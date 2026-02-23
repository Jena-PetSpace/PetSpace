import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../themes/app_theme.dart';

class OptimizedImage extends StatelessWidget {
  final String? imageUrl;
  final String? localPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableMemoryCache;
  final bool enableDiskCache;
  final Duration? fadeInDuration;
  final Duration? placeholderFadeInDuration;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const OptimizedImage({
    super.key,
    this.imageUrl,
    this.localPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.enableMemoryCache = true,
    this.enableDiskCache = true,
    this.fadeInDuration,
    this.placeholderFadeInDuration,
    this.memCacheWidth,
    this.memCacheHeight,
  }) : assert(imageUrl != null || localPath != null, 'Either imageUrl or localPath must be provided');

  @override
  Widget build(BuildContext context) {
    Widget image;

    if (localPath != null) {
      image = _buildLocalImage();
    } else {
      image = _buildNetworkImage();
    }

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: image,
    );
  }

  Widget _buildLocalImage() {
    return Image.file(
      File(localPath!),
      width: width,
      height: height,
      fit: fit,
      cacheWidth: memCacheWidth,
      cacheHeight: memCacheHeight,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _buildDefaultErrorWidget();
      },
    );
  }

  Widget _buildNetworkImage() {
    // Fix legacy URL format: /public/posts/ -> /public/images/posts/
    String fixedUrl = imageUrl!;
    if (fixedUrl.contains('/storage/v1/object/public/posts/') &&
        !fixedUrl.contains('/storage/v1/object/public/images/posts/')) {
      fixedUrl = fixedUrl.replaceFirst(
        '/storage/v1/object/public/posts/',
        '/storage/v1/object/public/images/posts/',
      );
    }

    return CachedNetworkImage(
      imageUrl: fixedUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _buildDefaultPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildDefaultErrorWidget(),
      fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 300),
      placeholderFadeInDuration: placeholderFadeInDuration ?? const Duration(milliseconds: 300),
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      useOldImageOnUrlChange: true,
      cacheManager: enableDiskCache ? null : null, // Custom cache manager could be used here
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.grey,
        size: 32.w,
      ),
    );
  }
}

class OptimizedProfileImage extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? fallbackText;
  final Color? backgroundColor;

  const OptimizedProfileImage({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.fallbackText,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: OptimizedImage(
                imageUrl: imageUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                memCacheWidth: (radius * 2 * 2).toInt(), // 2x for high DPI
                memCacheHeight: (radius * 2 * 2).toInt(),
                placeholder: _buildPlaceholder(),
                errorWidget: _buildFallback(),
              ),
            )
          : _buildFallback(),
    );
  }

  Widget _buildPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1),
      ),
      child: Center(
        child: fallbackText != null && fallbackText!.isNotEmpty
            ? Text(
                fallbackText![0].toUpperCase(),
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              )
            : Icon(
                Icons.person,
                size: radius * 0.8,
                color: AppTheme.primaryColor,
              ),
      ),
    );
  }
}

class OptimizedImageGallery extends StatelessWidget {
  final List<String> imageUrls;
  final double aspectRatio;
  final BorderRadius? borderRadius;
  final int maxDisplayCount;

  const OptimizedImageGallery({
    super.key,
    required this.imageUrls,
    this.aspectRatio = 1.0,
    this.borderRadius,
    this.maxDisplayCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    final displayUrls = imageUrls.take(maxDisplayCount).toList();
    final remainingCount = imageUrls.length - maxDisplayCount;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: _buildGalleryLayout(displayUrls, remainingCount),
    );
  }

  Widget _buildGalleryLayout(List<String> urls, int remainingCount) {
    switch (urls.length) {
      case 1:
        return _buildSingleImage(urls[0]);
      case 2:
        return _buildTwoImages(urls);
      case 3:
        return _buildThreeImages(urls);
      default:
        return _buildFourImages(urls, remainingCount);
    }
  }

  Widget _buildSingleImage(String url) {
    return OptimizedImage(
      imageUrl: url,
      fit: BoxFit.cover,
      borderRadius: borderRadius,
      memCacheWidth: 800,
      memCacheHeight: 800,
    );
  }

  Widget _buildTwoImages(List<String> urls) {
    return Row(
      children: [
        Expanded(
          child: OptimizedImage(
            imageUrl: urls[0],
            fit: BoxFit.cover,
            borderRadius: borderRadius,
            memCacheWidth: 400,
            memCacheHeight: 400,
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: OptimizedImage(
            imageUrl: urls[1],
            fit: BoxFit.cover,
            borderRadius: borderRadius,
            memCacheWidth: 400,
            memCacheHeight: 400,
          ),
        ),
      ],
    );
  }

  Widget _buildThreeImages(List<String> urls) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OptimizedImage(
            imageUrl: urls[0],
            fit: BoxFit.cover,
            borderRadius: borderRadius,
            memCacheWidth: 400,
            memCacheHeight: 400,
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: OptimizedImage(
                  imageUrl: urls[1],
                  fit: BoxFit.cover,
                  borderRadius: borderRadius,
                  memCacheWidth: 200,
                  memCacheHeight: 200,
                ),
              ),
              SizedBox(height: 2.h),
              Expanded(
                child: OptimizedImage(
                  imageUrl: urls[2],
                  fit: BoxFit.cover,
                  borderRadius: borderRadius,
                  memCacheWidth: 200,
                  memCacheHeight: 200,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFourImages(List<String> urls, int remainingCount) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: OptimizedImage(
                  imageUrl: urls[0],
                  fit: BoxFit.cover,
                  borderRadius: borderRadius,
                  memCacheWidth: 200,
                  memCacheHeight: 200,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: OptimizedImage(
                  imageUrl: urls[1],
                  fit: BoxFit.cover,
                  borderRadius: borderRadius,
                  memCacheWidth: 200,
                  memCacheHeight: 200,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2.h),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: OptimizedImage(
                  imageUrl: urls[2],
                  fit: BoxFit.cover,
                  borderRadius: borderRadius,
                  memCacheWidth: 200,
                  memCacheHeight: 200,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    OptimizedImage(
                      imageUrl: urls[3],
                      fit: BoxFit.cover,
                      borderRadius: borderRadius,
                      memCacheWidth: 200,
                      memCacheHeight: 200,
                    ),
                    if (remainingCount > 0)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: borderRadius,
                        ),
                        child: Center(
                          child: Text(
                            '+$remainingCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}