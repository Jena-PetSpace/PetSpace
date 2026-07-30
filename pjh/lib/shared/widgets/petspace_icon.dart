import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/petspace_icon_asset.dart';

class PetSpaceIcon extends StatelessWidget {
  const PetSpaceIcon({
    super.key,
    required this.asset,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final PetSpaceIconAsset asset;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? asset.defaultSize;
    final resolvedColor = color ?? IconTheme.of(context).color;
    final image = switch (asset.format) {
      PetSpaceIconFormat.svg => SvgPicture.asset(
          asset.path,
          width: resolvedSize,
          height: resolvedSize,
          colorFilter:
              asset.tone == PetSpaceIconTone.mono && resolvedColor != null
                  ? ColorFilter.mode(resolvedColor, BlendMode.srcIn)
                  : null,
        ),
      PetSpaceIconFormat.raster => Image.asset(
          asset.path,
          width: resolvedSize,
          height: resolvedSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
    };

    final label = semanticLabel;
    if (label == null) {
      return ExcludeSemantics(child: image);
    }

    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(child: image),
    );
  }
}
