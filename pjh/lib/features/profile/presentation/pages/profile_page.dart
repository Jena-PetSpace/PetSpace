import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../social/presentation/bloc/profile_bloc.dart';
import '../../../../config/injection_container.dart' as di;
import '../../../auth/presentation/bloc/auth_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 현재 로그인한 사용자 ID 가져오기
    final authState = context.watch<AuthBloc>().state;
    String? currentUserId;

    if (authState is AuthAuthenticated) {
      currentUserId = authState.user.id;
    }

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(
          child: Text('로그인이 필요합니다'),
        ),
      );
    }

    return BlocProvider(
      create: (context) => di.sl<ProfileBloc>()
        ..add(LoadUserProfileRequested(
          userId: currentUserId!,
          currentUserId: currentUserId,
        )),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('프로필'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () {
                context.push('/profile/settings');
              },
              icon: const Icon(Icons.settings),
            ),
          ],
        ),
        body: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ProfileError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.message),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ProfileBloc>().add(
                          LoadUserProfileRequested(
                            userId: currentUserId!,
                            currentUserId: currentUserId,
                          ),
                        );
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              );
            }

            if (state is ProfileLoaded) {
              final user = state.user;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50.w,
                      backgroundImage: user.profileImageUrl != null
                          ? NetworkImage(user.profileImageUrl!)
                          : null,
                      child: user.profileImageUrl == null
                          ? Icon(Icons.person, size: 50.w)
                          : null,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      SizedBox(height: 16.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.w),
                        child: Text(
                          user.bio!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14.sp),
                        ),
                      ),
                    ],
                    SizedBox(height: 24.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatItem('게시물', user.postsCount),
                        SizedBox(width: 24.w),
                        _buildStatItem('팔로워', user.followersCount),
                        SizedBox(width: 24.w),
                        _buildStatItem('팔로잉', user.followingCount),
                      ],
                    ),
                    SizedBox(height: 32.h),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.push('/profile/edit');
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('프로필 편집'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 32.w,
                          vertical: 16.h,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return const Center(child: Text('프로필을 불러올 수 없습니다'));
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}