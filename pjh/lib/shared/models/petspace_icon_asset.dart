enum PetSpaceIconFormat { svg, raster }

enum PetSpaceIconTone { mono, originalColor }

enum PetSpaceIconAsset {
  actionClose(
    path: 'assets/svg/icon_close.svg',
    format: PetSpaceIconFormat.svg,
    tone: PetSpaceIconTone.mono,
    defaultSize: 24,
  ),
  quickPlace(
    path: 'assets/images/quick_actions/quick_place.png',
    format: PetSpaceIconFormat.raster,
    tone: PetSpaceIconTone.originalColor,
    defaultSize: 30,
  ),
  quickMbti(
    path: 'assets/images/quick_actions/quick_mbti.png',
    format: PetSpaceIconFormat.raster,
    tone: PetSpaceIconTone.originalColor,
    defaultSize: 31,
  ),
  quickWalk(
    path: 'assets/images/quick_actions/quick_walk.png',
    format: PetSpaceIconFormat.raster,
    tone: PetSpaceIconTone.originalColor,
    defaultSize: 32,
  ),
  quickFortune(
    path: 'assets/images/quick_actions/quick_fortune.png',
    format: PetSpaceIconFormat.raster,
    tone: PetSpaceIconTone.originalColor,
    defaultSize: 31,
  ),
  quickQuiz(
    path: 'assets/images/quick_actions/quick_quiz.png',
    format: PetSpaceIconFormat.raster,
    tone: PetSpaceIconTone.originalColor,
    defaultSize: 31,
  );

  const PetSpaceIconAsset({
    required this.path,
    required this.format,
    required this.tone,
    required this.defaultSize,
  });

  final String path;
  final PetSpaceIconFormat format;
  final PetSpaceIconTone tone;
  final double defaultSize;
}
