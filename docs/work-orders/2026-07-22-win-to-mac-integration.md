# Windows → Mac integration 작업지시서 v3

## 고정 기준

- Base: `024d6855976cdc1e679cd87481d100a3121ff5dd`
- Source Ours: `ba06bb55a28e82b20ff7ac34feb78a8cefcf1b95`
- Theirs: `b1f6b48e32dd3046503abe3b54aa2934f48a056b`
- 기획 비준 뒤 이 문서와 세 manifest만 로컬 커밋하고 SHA를 PRE_MERGE_HEAD로 기록한다.
- merge는 PRE_MERGE_HEAD에서 실행한다. Source Ours는 ba06bb5로 계속 고정하며 push하지 않는다.

## 정본 manifest

- [merge_import_manifest](2026-07-22-win-to-mac-merge-import-manifest.md): 자동 유입 223, 수동 수정 대상 아님
- [resolution_manifest](2026-07-22-win-to-mac-resolution-manifest.md): content 36 + delete/modify 1 = 37
- [post_merge_edit_manifest](2026-07-22-win-to-mac-post-merge-edit-manifest.md): 후속 변경 허용 7

정상적인 merge_import 223파일 유입은 범위 위반이 아니다. 범위 위반 판정은 수동 수정과 승인된 생성 명령 결과에만 적용한다.

## 보존 및 중단 조건

Apple 로그인·OAuth, URL scheme, entitlements, plist, Xcode signing, iPad shareOrigin, b7b948e health guard, K1 block/privacy와 신규 auth.uid 기반 RPC를 보존한다. 광범위 users SELECT와 구형 caller-id RPC 복구, 파일 단위 ours/theirs 선택을 금지한다.

Base/Ours/Theirs/PRE_MERGE_HEAD 불일치, blocker/high, Codex·Claude 불일치, manifest 밖 수동 변경, 비밀 노출, K1/H2/Apple 인증 의미 변경, 신규 검증 실패가 발생하면 중단한다. DB·Edge·APNs·signing·TestFlight·배포를 실행하지 않는다.

## inspection manifest

add_pet 판단:

| path | Ref | SHA-256 |
|---|---|---|
| `pjh/lib/features/pets/presentation/widgets/add_pet_bottom_sheet.dart` | Ours | `e971068a62a12dfdaee419297d1487a3f009e8f89bdf6ea3cfa7ce98f32502e6` |
| `pjh/lib/features/pets/presentation/pages/pet_editor_page.dart` | Theirs | `ee3aebcc76a566e50b1339be9b1dec2af50be9ffebba098cafecaed2e01ba031` |
| `pjh/lib/features/pets/presentation/widgets/pet_editor_form_widgets.dart` | Theirs | `219982f735924dda208042390bf3adaa4b70c8942653c26cf6e548cafc307b92` |
| `pjh/test/features/pets/presentation/pages/pet_editor_page_test.dart` | Theirs | `4b2bf23664de4db813fcf63ba7e4439863f7508463b9af9dad5d71eea3cf9a43` |
| `pjh/test/features/pets/presentation/pages/pet_management_page_test.dart` | Theirs | `5ab434ca00d6b475eb2eeccd861eb5f661702882bd27b014efa230ecdfbb284b` |
| `pjh/test/features/pets/presentation/widgets/pet_card_test.dart` | Theirs | `8595f5f52363fae8068012fd1028e3520c2461259a4e6d9c0aeecc6d729deec8` |

Governance: `AGENTS.md`, `CLAUDE.md`, `.gitignore`, `.codex/config.toml`, `docs/AGENT_COLLABORATION.md`, `docs/MAC_MINI_HANDOFF.md`, `docs/README.md`.

iOS 보호: `pjh/ios/Podfile`, `pjh/ios/Podfile.lock`, `pjh/ios/Runner/Runner.entitlements`, `pjh/ios/Runner/Info.plist`, `pjh/ios/Runner.xcodeproj/project.pbxproj`, `pjh/lib/firebase_options.dart`, `pjh/lib/core/utils/share_origin.dart`, `pjh/lib/features/auth/data/repositories/auth_repository_impl.dart`, `supabase/petspace_setup.sql`.

K1: `supabase/migrations/K1_block_privacy_contract.sql`. H2: `supabase/migrations/H2_social_email_linking.sql`.

GoogleService-Info.plist는 local present=true와 merge 전후 보존 boolean만 검증한다. 내용과 해시는 문서·manifest·Claude 번들에서 제외한다.

## 테스트 47

| path | Theirs SHA-256 |
|---|---|
| `pjh/test/contracts/h1_health_contract_test.dart` | `796730846d74bbf805140dde4e39350ab1088d632f11fe838a4cd7e0560bc353` |
| `pjh/test/contracts/h1b_health_ui_contract_test.dart` | `76acb1dbe8e43fc0d9561e87e96bde3af2cd449648c949c1df8c73b6a2c9a5ee` |
| `pjh/test/contracts/p2b_block_privacy_contract_test.dart` | `b85863368c906aefdc5a2a8fd006e0b718ec2eede3e787aaab77eba1704c5e7e` |
| `pjh/test/features/auth/presentation/bloc/auth_bloc_test.dart` | `22607703142b1faef8a746fa5294119fe2907a571e78ef7415af5ac6a66db385` |
| `pjh/test/features/chat/data/repositories/chat_repository_impl_test.dart` | `50fc378c3ca12de8d2887b9d51f0770c248191e20e0709457e6a591bbd636f67` |
| `pjh/test/features/chat/presentation/bloc/chat_detail/chat_detail_bloc_test.dart` | `d54a80930a6d5966e631b54024db8e807f2289fd9fa36713c44748cbf143c5c4` |
| `pjh/test/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc_test.dart` | `7fd1d9f217417fbebc9a33973a848d3400501c9330eca9411a344da39f5b2163` |
| `pjh/test/features/chat/presentation/pages/chat_detail_page_test.dart` | `5a36e6a98d4f0002de2b37232727211d538e31738d7e5902f0e23f59e8beec3d` |
| `pjh/test/features/chat/presentation/pages/chat_room_settings_page_test.dart` | `f055e4d2f699b793d72b59101434b5ae1201561c252b093a43f111eb5544b07a` |
| `pjh/test/features/chat/presentation/pages/chat_rooms_page_test.dart` | `2fb27c9a37f865ab9d8fb80cd2f41efd5be5cfc3e53643ef1a36543da12beb48` |
| `pjh/test/features/chat/presentation/pages/create_chat_page_test.dart` | `2cd3f41343b1b88a3f4a31d41503533de65aa9c279f5dd0f107a5f52df06eac6` |
| `pjh/test/features/chat/presentation/widgets/chat_bubble_test.dart` | `5498fbfe79b5c3764da4cc4cdd28706f2dd7ff839ca2bbf54694a48869a9ec6f` |
| `pjh/test/features/chat/presentation/widgets/chat_input_bar_test.dart` | `378f05af95138104c5868bbc67d11ca8f7e4a125d50a6a562b5b894ffd114581` |
| `pjh/test/features/chat/presentation/widgets/chat_room_tile_test.dart` | `8490a67bfb5eb1c31da5d2cda5952be9cddb16848435d0e50fa2e442f80f89c9` |
| `pjh/test/features/health/domain/entities/health_record_test.dart` | `f37d3da0468f82f204975dc00ddd047883d1d8720c5974486ba2cc6ddd4d39bf` |
| `pjh/test/features/health/domain/usecases/health_usecases_test.dart` | `1ef3361e7a7bea4507958df1615de0f8f7670bd92a963956894f2e9b5f3aa9da` |
| `pjh/test/features/health/presentation/bloc/health_bloc_test.dart` | `c48d1c1b06164b406a55dfaac232a149832a699a3a0cd7a1c1fe4513c5a4dd25` |
| `pjh/test/features/health/presentation/health_alert_settings_page_test.dart` | `eaf010db86caa272b399b8806156868b61903c4af5743309c6df14ed40970cca` |
| `pjh/test/features/health/presentation/health_emotion_loader_test.dart` | `75585616c5683167c2d12412b61ef2a66dcef1e3100867cd624ed10d84059748` |
| `pjh/test/features/health/presentation/health_pdf_data_test.dart` | `f7122b024254544c6ae1fd88613d5a9772a246705d303b97945a2411eeba1b79` |
| `pjh/test/features/health/presentation/health_record_card_test.dart` | `582966ec44bfdf47eb16abc37369c96d805889ae79ca65e33cc151f3e8c7f4ca` |
| `pjh/test/features/pets/presentation/pages/pet_detail_page_test.dart` | `4a6fbf02de4c9313a1f7ef6257865de00bb9a96fdf838be1687a2c849c45f836` |
| `pjh/test/features/pets/presentation/pages/pet_editor_page_test.dart` | `4b2bf23664de4db813fcf63ba7e4439863f7508463b9af9dad5d71eea3cf9a43` |
| `pjh/test/features/pets/presentation/pages/pet_management_page_test.dart` | `5ab434ca00d6b475eb2eeccd861eb5f661702882bd27b014efa230ecdfbb284b` |
| `pjh/test/features/pets/presentation/widgets/pet_card_test.dart` | `8595f5f52363fae8068012fd1028e3520c2461259a4e6d9c0aeecc6d729deec8` |
| `pjh/test/features/profile/presentation/pages/community_guidelines_page_test.dart` | `15c30617e9ee59650d004a19a623c913f7ab51dcb61bf85b0776faf258e10c81` |
| `pjh/test/features/profile/presentation/pages/help_page_test.dart` | `3521f1d74bca74a7b47252cbc6583d0d2c2667947f7b06a5f6c27e3a516438e4` |
| `pjh/test/features/profile/presentation/pages/notification_settings_page_test.dart` | `82582201a988005ebabb4cfb985e5925ce17cfae83739916ec592475cbf1e21c` |
| `pjh/test/features/profile/presentation/pages/privacy_settings_page_test.dart` | `1c94f4aa3857ef736fb8e9d3195ec15c3683e5bd46b3a66afe6a308d8787e729` |
| `pjh/test/features/profile/presentation/pages/profile_edit_page_test.dart` | `27e2ae29f0790d663fe1e59ea2efbb1de1bccda09b6afe3639528bec928c6cee` |
| `pjh/test/features/social/presentation/pages/explore_route_test.dart` | `fb7f625b08fb1d0f40f2b9f1f72837ce085426d8f8b0c9f6e201c49f42cf3bd7` |
| `pjh/test/features/social/presentation/pages/feed_comments_entry_test.dart` | `abe627eb1c89c973a1063a1f6e1ca4ed2ec86acca5a998c9c50e1b5b4a69c258` |
| `pjh/test/features/social/presentation/pages/feed_page_state_test.dart` | `bc72eece0aa28a681ad79b55aade69edfbc98a07ee6e1bce382759df74e772fd` |
| `pjh/test/features/social/presentation/pages/followers_page_test.dart` | `2e6fb1d2125dcbae8d8dfcf31eea6bbc4e8cd036f8d413234f717b477eea4a4f` |
| `pjh/test/features/social/presentation/pages/hashtag_page_test.dart` | `e0921eb112c031a47ed4bbdbad9478da75a4e78882c43986eb404d8fcde03122` |
| `pjh/test/features/social/presentation/pages/location_posts_page_test.dart` | `eecf42c5592c41594dd1d3b0eedb4729e892595ceb748a5e3c2ae51cb6e8438e` |
| `pjh/test/features/social/presentation/pages/post_detail_page_test.dart` | `0d159549116593c02b0080d497a651a087370810a1495e56c9f6f2a588fe7980` |
| `pjh/test/features/social/presentation/pages/profile_page_test.dart` | `006e2a15d146785c4faa731a2bf6fa10d3f220bb651742a16c70cfaa85b743ac` |
| `pjh/test/features/social/presentation/pages/search_page_test.dart` | `48ee9fac0bc91eb89b661c793c0bb7e4a2a680d8c61bc5c7fb41d452e77197d8` |
| `pjh/test/features/social/presentation/widgets/collection_picker_sheet_test.dart` | `76f3d4fb48683e74e0eace2694b20a43986b70756bdd419aa9a31c6a3f563c56` |
| `pjh/test/features/social/presentation/widgets/comment_list_item_test.dart` | `417b73004a22342d18d455137762a6c3e1056c91f9e8449dc398e88855fd09b1` |
| `pjh/test/features/social/presentation/widgets/likes_bottom_sheet_test.dart` | `08f131692052deaac972a58cfa45def3e5810456e61449978dc43b249136e433` |
| `pjh/test/features/social/presentation/widgets/post_card_bookmark_test.dart` | `6d0cd216ada56ff96cc77ebfb709caec02edaf7f793ff632b4c6b3c3b28fa62f` |
| `pjh/test/features/social/presentation/widgets/post_card_connector_test.dart` | `168c61d986752ec95cc10da6a77510338bcbe233637c0890bf49c7be2c60ba6d` |
| `pjh/test/features/social/presentation/widgets/post_card_like_test.dart` | `565e4cbbe7c3d8946e9a08683c6dd6b635cf7ca685405cfbadf0ad824c547262` |
| `pjh/test/features/social/presentation/widgets/profile_stats_card_test.dart` | `c7612f3190430d501f14f96d352687f4ad6c0a0ff5a91871c5e4129fc6bbfaeb` |
| `pjh/test/shared/widgets/lazy_load_list_test.dart` | `eac486fe40afd9cf66616be55afcee7eb0f88945e7d23f96e02b3572e9674801` |

## 외부 전송과 실행 권한

- planning union: 중복 제거 106경로
- final union: 중복 제거 99경로
- 자동 유입 223 또는 전체 260파일은 새로 외부 전송하지 않는다. Theirs commit과 전체 테스트로 검증한다.
- 항상 제외: Google plist, .env*, secrets.dart, .claude/settings.json, 인증서·키·provisioning profile, 사용자 데이터·로그·빌드 생성물.
- Fable 5 기본, 429/usage/rate/session limit일 때만 동일 번들을 Opus 4.8로 1회 재시도한다.
- pubspec 의미 해결 → flutter pub get → pod install 순서의 생성 결과로만 Podfile.lock 변경을 허용하고 pod/plugin 변화 이유를 기록한다.

검증: format, analyze, 위 47경로 테스트, 전체 test, iOS release no-codesign build, git diff --check. mac-ios-release 반영·push·DB·Edge·APNs·signing·TestFlight·배포는 권한 밖이다.

## 기계 검증 결과

- Base→Theirs 변경: 260
- resolution: 37
- merge import: 223
- merge import missing/extra: 0/0
- resolution 중복: 0
- mode 형식 오류: 0
- Theirs blob OID 불일치: 0
- resolution Theirs SHA 불일치: 0
- 테스트 47 SHA 불일치: 0
- planning union: 106
- final union: 99

## SHA-256

- integration: `8d751e422a161d06436b1ad9640d70082ab3d0c124b2b92cb20897c198aeda8e`
- merge_import: `937483a35e2a617f684b3f08049c93f38f788636bdf6ed08a1ddd15c1f9d901a`
- resolution: `7a24af5ca31f3a6ebcf385c14cb7cb68ea3dbb79e7ab1984a6edff9f6560ca83`
- post_merge: `5509e278001ab450c18e5fd029252e9c7a86f9c5a22bdab9a055381e752b305b`
- 전체 manifest: `2eeb75b42d7505552d101f2f2a60c9444cee16c282ada27fe243d4dd94354846`

integration hash는 integration 값과 전체 manifest 값을 각각의 PENDING 문자열로 정규화한 이 파일의 SHA-256이다. 전체 hash는 전체 manifest 값만 V3_MANIFEST_SHA256_PENDING으로 정규화한 integration→merge_import→resolution→post_merge UTF-8 bytes 연결값이다.

## 단일 사용자 승인 문구

```text
본인은 v3 작업지시서와 세 manifest, Base/Ours/Theirs, 자동 유입 223파일,
37개 Git 충돌, post-merge 허용 7파일, planning union 106경로,
final union 99경로와 SHA-256을 확인했다.

이번 한 번의 승인으로 비밀 제외 106경로의 Claude Fable 5 기획 검토,
429/사용량 제한 시 Opus 4.8 1회 재시도, Codex·Claude 합의,
문서 4파일 로컬 커밋과 PRE_MERGE_HEAD 기록, 고정 Theirs merge,
37개 충돌 의미 병합, post-merge 7파일 후속 변경, format/analyze,
명시된 47개 테스트와 전체 test, iOS no-codesign build,
final union 중 실제 변경 파일의 Claude 최종 리뷰를 허용한다.

mac-ios-release 반영·push, 원격 push, DB/RPC 실행, Edge deploy,
APNs, signing, TestFlight, 스토어 배포는 승인하지 않는다.
중단 조건 발생 시 즉시 멈추고 재승인을 요청하라.
```
