import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../themes/app_theme.dart';

class DefaultAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? imageUrl;

  const DefaultAvatar({
    super.key,
    required this.name,
    required this.size,
    this.imageUrl,
  });

  static const List<Color> _avatarColors = [
    AppTheme.brandDeep, // Deep Blue
    Color(0xFF2C4482), // Indigo
    Color(0xFF0077B6), // Bright Blue
    AppTheme.infoSky, // Sky Blue
    AppTheme.success, // Green
    AppTheme.highlightColor, // Coral
    AppTheme.warning, // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00897B), // Teal
    Color(0xFF5C6BC0), // Indigo accent
  ];

  Color _colorForName(String name) {
    final index = name.hashCode.abs() % _avatarColors.length;
    return _avatarColors[index];
  }

  @override
  Widget build(BuildContext context) {
    final radius = size.r / 2;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Semantics(
        label: '$name 프로필 사진',
        image: true,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          imageBuilder: (context, imageProvider) => CircleAvatar(
            radius: radius,
            backgroundImage: imageProvider,
          ),
          placeholder: (context, url) => _buildFallback(radius),
          errorWidget: (context, url, error) => _buildFallback(radius),
        ),
      );
    }

    return Semantics(
      label: '$name 프로필 사진',
      image: true,
      child: _buildFallback(radius),
    );
  }

  Widget _buildFallback(double radius) {
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final color = _colorForName(name);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: (size * 0.4).sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
