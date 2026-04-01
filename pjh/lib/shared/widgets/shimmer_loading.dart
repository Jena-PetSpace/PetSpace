import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

/// 피드 로딩 Shimmer
class FeedShimmerLoading extends StatelessWidget {
  const FeedShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, __) => const _PostCardShimmer(),
    );
  }
}

class _PostCardShimmer extends StatelessWidget {
  const _PostCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 헤더
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 100.w, height: 12.h, color: Colors.white),
                    SizedBox(height: 4.h),
                    Container(width: 60.w, height: 10.h, color: Colors.white),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // 이미지 영역
            Container(
              width: double.infinity,
              height: 200.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            SizedBox(height: 12.h),
            // 텍스트 영역
            Container(
                width: double.infinity, height: 14.h, color: Colors.white),
            SizedBox(height: 6.h),
            Container(width: 200.w, height: 14.h, color: Colors.white),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}

/// 프로필 로딩 Shimmer
class ProfileShimmerLoading extends StatelessWidget {
  const ProfileShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // 프로필 사진
            Container(
              width: 80.w,
              height: 80.w,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(height: 12.h),
            Container(width: 120.w, height: 16.h, color: Colors.white),
            SizedBox(height: 8.h),
            Container(width: 80.w, height: 12.h, color: Colors.white),
            SizedBox(height: 24.h),
            // 통계
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                  3,
                  (_) => Column(
                        children: [
                          Container(
                              width: 30.w, height: 16.h, color: Colors.white),
                          SizedBox(height: 4.h),
                          Container(
                              width: 50.w, height: 12.h, color: Colors.white),
                        ],
                      )),
            ),
          ],
        ),
      ),
    );
  }
}

/// 알림 로딩 Shimmer
class NotificationShimmerLoading extends StatelessWidget {
  const NotificationShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: double.infinity,
                        height: 12.h,
                        color: Colors.white),
                    SizedBox(height: 6.h),
                    Container(width: 150.w, height: 10.h, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 검색 결과 로딩 Shimmer
class SearchShimmerLoading extends StatelessWidget {
  const SearchShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      children: [
        // 유저 섹션
        ...List.generate(3, (_) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Padding(
            padding: EdgeInsets.only(bottom: 14.h),
            child: Row(children: [
              Container(width: 44.w, height: 44.w, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              SizedBox(width: 12.w),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 100.w, height: 12.h, color: Colors.white),
                SizedBox(height: 5.h),
                Container(width: 60.w, height: 10.h, color: Colors.white),
              ])),
            ]),
          ),
        )),
        Divider(height: 20.h),
        // 게시글 섹션
        ...List.generate(2, (_) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 36.w, height: 36.w, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                SizedBox(width: 10.w),
                Container(width: 80.w, height: 10.h, color: Colors.white),
              ]),
              SizedBox(height: 10.h),
              Container(width: double.infinity, height: 100.h, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.r))),
              SizedBox(height: 8.h),
              Container(width: double.infinity, height: 10.h, color: Colors.white),
              SizedBox(height: 4.h),
              Container(width: 140.w, height: 10.h, color: Colors.white),
            ]),
          ),
        )),
      ],
    );
  }
}

/// 게시글 상세 로딩 Shimmer
class PostDetailShimmerLoading extends StatelessWidget {
  const PostDetailShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 작성자 헤더
          Row(children: [
            Container(width: 40.w, height: 40.w, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            SizedBox(width: 10.w),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 90.w, height: 12.h, color: Colors.white),
              SizedBox(height: 4.h),
              Container(width: 55.w, height: 10.h, color: Colors.white),
            ]),
          ]),
          SizedBox(height: 14.h),
          // 이미지
          Container(width: double.infinity, height: 220.h, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r))),
          SizedBox(height: 12.h),
          // 본문
          Container(width: double.infinity, height: 12.h, color: Colors.white),
          SizedBox(height: 6.h),
          Container(width: double.infinity, height: 12.h, color: Colors.white),
          SizedBox(height: 6.h),
          Container(width: 180.w, height: 12.h, color: Colors.white),
          SizedBox(height: 20.h),
          // 액션바
          Row(children: [
            Container(width: 60.w, height: 28.h, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r))),
            SizedBox(width: 10.w),
            Container(width: 60.w, height: 28.h, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r))),
          ]),
          Divider(height: 32.h),
          // 댓글 3개
          ...List.generate(3, (_) => Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 34.w, height: 34.w, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              SizedBox(width: 10.w),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 70.w, height: 10.h, color: Colors.white),
                SizedBox(height: 5.h),
                Container(width: double.infinity, height: 10.h, color: Colors.white),
                SizedBox(height: 4.h),
                Container(width: 120.w, height: 10.h, color: Colors.white),
              ])),
            ]),
          )),
        ]),
      ),
    );
  }
}

/// 댓글 목록 로딩 Shimmer
class CommentShimmerLoading extends StatelessWidget {
  const CommentShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36.w, height: 36.w, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            SizedBox(width: 10.w),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 70.w, height: 10.h, color: Colors.white),
                SizedBox(width: 8.w),
                Container(width: 40.w, height: 8.h, color: Colors.white),
              ]),
              SizedBox(height: 6.h),
              Container(width: double.infinity, height: 10.h, color: Colors.white),
              SizedBox(height: 4.h),
              Container(width: 140.w, height: 10.h, color: Colors.white),
            ])),
          ]),
        ),
      ),
    );
  }
}
