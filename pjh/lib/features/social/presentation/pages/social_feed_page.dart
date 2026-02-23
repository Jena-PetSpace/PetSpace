import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../bloc/social_bloc.dart';

class SocialFeedPage extends StatelessWidget {
  const SocialFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('소셜 피드'),
      ),
      body: BlocBuilder<SocialBloc, SocialState>(
        builder: (context, state) {
          if (state is SocialLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (state is SocialLoaded) {
            return ListView.builder(
              itemCount: state.posts.length,
              itemBuilder: (context, index) {
                final post = state.posts[index];
                return Card(
                  margin: EdgeInsets.all(8.w),
                  child: ListTile(
                    title: Text(post.content ?? '내용 없음', style: TextStyle(fontSize: 14.sp)),
                    subtitle: Text('작성자: ${post.authorId}', style: TextStyle(fontSize: 12.sp)),
                  ),
                );
              },
            );
          } else if (state is SocialError) {
            return Center(
              child: Text('오류: ${state.message}', style: TextStyle(fontSize: 14.sp)),
            );
          }
          return Center(
            child: Text('피드를 로드해주세요.', style: TextStyle(fontSize: 14.sp)),
          );
        },
      ),
    );
  }
}