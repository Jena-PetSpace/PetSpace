param(
  [Parameter(Mandatory = $true)]
  [string]$RepoRoot,

  [Parameter(Mandatory = $true)]
  [string]$ProvenanceManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$ProvenanceManifest = (Resolve-Path -LiteralPath $ProvenanceManifest).Path
$FlutterRoot = Join-Path $RepoRoot 'pjh'

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$Executable,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )

  Write-Host "`n== $Label =="
  Push-Location -LiteralPath $WorkingDirectory
  try {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "$Label failed with exit code $LASTEXITCODE."
    }
  }
  finally {
    Pop-Location
  }
}

function Invoke-FullSuiteWithInheritedBaseline {
  param(
    [Parameter(Mandatory = $true)][string]$WorkingDirectory
  )

  Write-Host "`n== Full Flutter test suite with exact inherited baseline =="
  $testNames = @{}
  $failureNames = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
  )
  $sawDoneEvent = $false

  Push-Location -LiteralPath $WorkingDirectory
  try {
    & flutter test --no-pub --machine 2>&1 | ForEach-Object {
      try {
        $event = $_ | ConvertFrom-Json -ErrorAction Stop
        if ($event.type -eq 'testStart') {
          $testNames[[string]$event.test.id] = [string]$event.test.name
        }
        elseif ($event.type -eq 'error') {
          $testId = [string]$event.testID
          $name = $testNames[$testId]
          if ([string]::IsNullOrWhiteSpace($name)) {
            $name = "<unknown:$testId>"
          }
          [void]$failureNames.Add($name)
        }
        elseif ($event.type -eq 'done') {
          $sawDoneEvent = $true
        }
      }
      catch {
        # flutter tool diagnostics are not JSON machine events. They are not
        # treated as test names; a non-test infrastructure failure is caught
        # below by the native exit code plus the unknown/missing comparison.
      }
    }
    $testExitCode = $LASTEXITCODE
  }
  finally {
    Pop-Location
  }

  if (-not $sawDoneEvent) {
    throw (
      'Flutter machine output ended without a terminal done event. ' +
      "Treat this as an infrastructure/test-run failure (exit code: $testExitCode)."
    )
  }

  $expectedFailures = @(
    'SaveAnalysisRequested 저장할 분석 없으면 Error emit',
    'GetHealthRecords 성공 → Right(List<HealthRecord>)',
    'AddHealthRecord 성공 → Right(HealthRecord)',
    'AddHealthRecord 실패 → Left(DatabaseFailure)',
    'UpdateHealthRecord 성공 → Right(HealthRecord)'
  )
  $actualFailures = @($failureNames | Sort-Object)
  $unexpected = @($actualFailures | Where-Object { $_ -notin $expectedFailures })
  $missing = @($expectedFailures | Where-Object { $_ -notin $actualFailures })

  if ($unexpected.Count -gt 0 -or $missing.Count -gt 0) {
    throw (
      "Full-suite failure baseline changed.`n" +
      "Unexpected:`n$($unexpected -join "`n")`n" +
      "Missing expected:`n$($missing -join "`n")`n" +
      "flutter exit code: $testExitCode"
    )
  }
  if ($testExitCode -eq 0) {
    throw 'Flutter reported success while the exact inherited failures were observed.'
  }

  Write-Host (
    'No integration regressions: the only full-suite failures are the five ' +
    'inherited test-contract failures assigned to the next two-test-file wave.'
  )
}

function Get-ChangedPaths {
  $tracked = & git -C $RepoRoot -c core.quotepath=false diff `
    --name-only --diff-filter=ACDMRTUXB
  if ($LASTEXITCODE -ne 0) {
    throw 'git diff --name-only failed.'
  }
  $untracked = & git -C $RepoRoot -c core.quotepath=false ls-files `
    --others --exclude-standard
  if ($LASTEXITCODE -ne 0) {
    throw 'git ls-files --others failed.'
  }
  return @(
    @($tracked) + @($untracked) |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { $_.Replace('\', '/') } |
      Sort-Object -Unique
  )
}

function Assert-ExactScope {
  $allowed = @(
    Import-Csv -LiteralPath $ProvenanceManifest -Delimiter "`t" |
      ForEach-Object { $_.path.Replace('\', '/') } |
      Sort-Object -Unique
  )
  $actual = Get-ChangedPaths
  $outside = @($actual | Where-Object { $_ -notin $allowed })
  if ($outside.Count -gt 0) {
    throw "Changed paths outside the 80-path integration scope:`n$($outside -join "`n")"
  }

  $notDirty = @($allowed | Where-Object { $_ -notin $actual })
  Write-Host "Actual changed paths: $($actual.Count)"
  Write-Host "Allowed union paths: $($allowed.Count)"
  Write-Host "Allowed paths identical to HEAD after integration: $($notDirty.Count)"
}

function Assert-ProtectedPaths {
  $relativePaths = @(
    'pjh/lib/features/social/presentation/pages/home_page.dart'
  )
  $relativePaths += @(
    Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'pjh/lib/features/home') -File -Recurse |
      ForEach-Object {
        $_.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
      }
  )
  $relativePaths += @(
    Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'pjh/lib/features/emotion/presentation') -File -Recurse |
      ForEach-Object {
        $_.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
      }
  )

  foreach ($relative in ($relativePaths | Sort-Object -Unique)) {
    $headBlob = (& git -C $RepoRoot rev-parse "HEAD:$relative").Trim()
    if ($LASTEXITCODE -ne 0) {
      throw "Could not resolve protected HEAD blob: $relative"
    }
    $absolute = Join-Path $RepoRoot $relative
    $workBlob = (& git -C $RepoRoot hash-object "--path=$relative" $absolute).Trim()
    if ($LASTEXITCODE -ne 0) {
      throw "Could not hash protected path: $relative"
    }
    if ($headBlob -ne $workBlob) {
      throw "Protected path changed: $relative"
    }
  }

  $mainNavigation = 'pjh/lib/main_navigation.dart'
  $p2Row = Import-Csv -LiteralPath $ProvenanceManifest -Delimiter "`t" |
    Where-Object { $_.source -eq 'P2' -and $_.path -eq $mainNavigation } |
    Select-Object -First 1
  if ($null -eq $p2Row) {
    throw 'P2 main_navigation.dart provenance row is missing.'
  }
  $mainNavigationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $RepoRoot $mainNavigation)
  ).Hash.ToLowerInvariant()
  if ($mainNavigationHash -ne $p2Row.sha256.ToLowerInvariant()) {
    throw 'main_navigation.dart differs from the approved P2 source.'
  }

  Write-Host "Protected Home/AI paths: $($relativePaths.Count) unchanged"
  Write-Host 'Bottom-navigation host matches the approved P2 source.'
}

function Assert-ForbiddenSymbols {
  $pattern = @(
    'PushNotificationService',
    'sendLikeNotification',
    'getBlockedUsersDetailed',
    'blockUser\(String blockerId',
    'unblockUser\(String blockerId',
    'createNotification\('
  ) -join '|'
  $matches = & rg -n $pattern (Join-Path $RepoRoot 'pjh/lib')
  if ($LASTEXITCODE -eq 0) {
    throw "Forbidden legacy symbols remain:`n$($matches -join "`n")"
  }
  if ($LASTEXITCODE -ne 1) {
    throw 'Forbidden-symbol scan failed.'
  }
}

function Assert-FeedBlocTestCompatibility {
  $testPath = Join-Path $RepoRoot 'pjh/test/features/social/presentation/bloc/feed_bloc_test.dart'
  $source = Get-Content -LiteralPath $testPath -Raw -Encoding utf8
  foreach ($forbidden in @(
    'PushNotificationService',
    'pushNotificationService:',
    'sendLikeNotification'
  )) {
    if ($source.Contains($forbidden)) {
      throw "feed_bloc_test.dart restored a deleted direct-push seam: $forbidden"
    }
  }
  foreach ($required in @(
    'serializes one post and ignores its realtime echo while pending',
    'failed mutation rolls back only its target post'
  )) {
    if (-not $source.Contains($required)) {
      throw "feed_bloc_test.dart lost SOCIAL-I1 regression coverage: $required"
    }
  }
}

$p1Tests = @(
  'test/core/services/app_package_info_test.dart',
  'test/features/my/presentation/pages/my_page_test.dart',
  'test/features/my/presentation/pages/my_settings_page_test.dart',
  'test/features/my/presentation/widgets/saved_posts_grid_test.dart',
  'test/features/profile/presentation/pages/help_page_test.dart',
  'test/features/profile/presentation/pages/profile_edit_page_test.dart',
  'test/features/social/presentation/widgets/user_posts_list_test.dart'
)

$n1Tests = @(
  'test/features/social/data/repositories/social_repository_impl_follow_test.dart',
  'test/features/social/presentation/bloc/comment_bloc_test.dart',
  'test/features/social/presentation/pages/followers_page_test.dart',
  'test/features/social/presentation/pages/post_detail_page_test.dart',
  'test/features/social/presentation/pages/profile_page_test.dart',
  'test/features/social/presentation/widgets/comment_list_item_test.dart',
  'test/features/social/presentation/widgets/profile_stats_card_test.dart',
  'test/features/social/presentation/widgets/user_list_tile_test.dart',
  'test/features/social/presentation/widgets/user_posts_list_test.dart'
)

$n2Tests = @(
  'test/features/my/presentation/pages/my_page_test.dart',
  'test/features/my/presentation/pages/my_saved_posts_page_test.dart',
  'test/features/my/presentation/widgets/saved_posts_grid_test.dart',
  'test/features/social/data/repositories/social_repository_impl_bookmark_test.dart',
  'test/features/social/domain/entities/saved_posts_page_test.dart',
  'test/features/social/presentation/bloc/bookmark_bloc_test.dart',
  'test/features/social/presentation/pages/post_detail_page_test.dart',
  'test/features/social/presentation/utils/saved_posts_change_notifier_test.dart',
  'test/features/social/presentation/widgets/collection_picker_sheet_test.dart',
  'test/features/social/presentation/widgets/post_card_bookmark_test.dart'
)

$socialI1Tests = @(
  'test/features/social/data/datasources/social_remote_data_source_impl_like_test.dart',
  'test/features/social/data/repositories/social_repository_impl_like_test.dart',
  'test/features/social/domain/entities/post_likes_page_test.dart',
  'test/features/social/presentation/bloc/feed_bloc_test.dart',
  'test/features/social/presentation/pages/feed_comments_entry_test.dart',
  'test/features/social/presentation/pages/post_detail_page_test.dart',
  'test/features/social/presentation/widgets/comment_list_item_test.dart',
  'test/features/social/presentation/widgets/comments_bottom_sheet_test.dart',
  'test/features/social/presentation/widgets/likes_bottom_sheet_test.dart',
  'test/features/social/presentation/widgets/post_card_like_test.dart'
)

$p2Tests = @(
  'test/contracts/p2a1_notification_contract_test.dart',
  'test/contracts/p2b_block_privacy_contract_test.dart',
  'test/core/services/profile_service_test.dart',
  'test/features/chat/data/repositories/chat_block_filter_test.dart',
  'test/features/profile/presentation/pages/privacy_settings_page_test.dart',
  'test/features/social/data/models/notification_model_test.dart',
  'test/features/social/data/repositories/social_repository_impl_block_test.dart',
  'test/features/social/data/repositories/social_repository_impl_follow_test.dart',
  'test/features/social/presentation/bloc/comment_bloc_test.dart',
  'test/features/social/presentation/bloc/notification_badge_bloc_test.dart',
  'test/features/social/presentation/pages/followers_page_test.dart',
  'test/features/social/presentation/pages/post_detail_page_test.dart',
  'test/features/social/presentation/pages/profile_page_test.dart'
)

$allRequiredTests = @(
  $p1Tests + $n1Tests + $n2Tests + $socialI1Tests + $p2Tests |
    Sort-Object -Unique
)
foreach ($test in $allRequiredTests) {
  if (-not (Test-Path -LiteralPath (Join-Path $FlutterRoot $test) -PathType Leaf)) {
    throw "Required regression test is missing: $test"
  }
}

Assert-ExactScope
Assert-ProtectedPaths
Assert-ForbiddenSymbols
Assert-FeedBlocTestCompatibility

$changedDart = @(
  Get-ChangedPaths |
    Where-Object {
      $_.EndsWith('.dart') -and
      $_ -ne 'pjh/lib/main_navigation.dart' -and
      (Test-Path -LiteralPath (Join-Path $RepoRoot $_) -PathType Leaf)
    } |
    ForEach-Object { $_.Substring('pjh/'.Length) }
)
if ($changedDart.Count -gt 0) {
  Invoke-Step 'Dart format check' $FlutterRoot 'dart' (
    @('format', '--output=none', '--set-exit-if-changed') + $changedDart
  )
}

Invoke-Step 'Flutter analyze' $FlutterRoot 'flutter' @('analyze', '--no-pub')
Invoke-Step 'P1 regression' $FlutterRoot 'flutter' (@('test', '--no-pub') + $p1Tests)
Invoke-Step 'N1 regression' $FlutterRoot 'flutter' (@('test', '--no-pub') + $n1Tests)
Invoke-Step 'N2 regression' $FlutterRoot 'flutter' (@('test', '--no-pub') + $n2Tests)
Invoke-Step 'SOCIAL-I1 regression' $FlutterRoot 'flutter' (@('test', '--no-pub') + $socialI1Tests)
Invoke-Step 'P2A/P2B regression' $FlutterRoot 'flutter' (@('test', '--no-pub') + $p2Tests)
Invoke-FullSuiteWithInheritedBaseline $FlutterRoot
Invoke-Step 'Git diff check' $RepoRoot 'git' @('diff', '--check')

Assert-ExactScope
Assert-ProtectedPaths
Assert-ForbiddenSymbols
Assert-FeedBlocTestCompatibility
Write-Host "`nMY-CLOSE integration verification passed."
