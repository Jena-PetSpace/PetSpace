import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../config/injection_container.dart' as di;
import '../../../social/presentation/bloc/profile_bloc.dart';
import '../../../social/presentation/pages/profile_page.dart' as social;

/// 내 프로필 진입점 — AuthBloc에서 currentUserId를 읽어
/// social/ProfilePage로 위임합니다.
///
/// social/ProfilePage(타인 프로필)와 동일한 UI를 공유하되,
/// 자기 자신의 userId를 자동 주입합니다.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    if (authState is! AuthAuthenticated) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    final myId = authState.user.id;

    return BlocProvider(
      create: (_) => di.sl<ProfileBloc>()
        ..add(LoadUserProfileRequested(
          userId: myId,
          currentUserId: myId,
        )),
      child: social.ProfilePage(
        userId: myId,
        currentUserId: myId,
        isMyProfile: true,
      ),
    );
  }
}
