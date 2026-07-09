part of 'post_card.dart';

extension _PostCardMedia on _PostCardState {
  void _onDoubleTapImage() {
    if (!post.isLikedByCurrentUser) {
      widget.onLike();
    }
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageViewerPage(
          imageUrls: post.imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildImages() {
    if (post.imageUrls.length == 1) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: GestureDetector(
          onTap: () => _openViewer(context, 0),
          onDoubleTap: _onDoubleTapImage,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CachedNetworkImage(
                imageUrl: post.imageUrls.first,
                width: double.infinity,
                height: 300.h,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 300.h,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 300.h,
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: AppTheme.errorColor, size: 24.w),
                      SizedBox(height: 8.h),
                      Text('이미지 로드 실패',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 14.sp)),
                    ],
                  ),
                ),
              ),
              if (_showHeart) _DoubleTapHeart(size: 80.w),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Column(
        children: [
          SizedBox(
            height: 300.h,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  itemCount: post.imageUrls.length,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _openViewer(context, index),
                      onDoubleTap: _onDoubleTapImage,
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrls[index],
                        width: double.infinity,
                        height: 300.h,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 300.h,
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 300.h,
                          color: Colors.grey[200],
                          child: Icon(Icons.error, color: AppTheme.errorColor, size: 24.w),
                        ),
                      ),
                    );
                  },
                ),
                if (_showHeart) _DoubleTapHeart(size: 80.w),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(post.imageUrls.length, (index) {
              return Container(
                width: _currentImageIndex == index ? 8.w : 6.w,
                height: _currentImageIndex == index ? 8.w : 6.w,
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentImageIndex == index
                      ? AppTheme.primaryColor
                      : Colors.grey[300],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
