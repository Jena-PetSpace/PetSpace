import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/follow.dart';
import '../../domain/repositories/social_repository.dart';
import '../../../../config/injection_container.dart' as di;
import '../widgets/user_list_tile.dart';

class FollowersPage extends StatefulWidget {
  final String userId;
  final String userName;

  const FollowersPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SocialRepository _repository;

  List<Follow> _followers = [];
  List<Follow> _following = [];
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;
  String? _followersError;
  String? _followingError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repository = di.sl<SocialRepository>();

    _loadFollowers();
    _loadFollowing();
  }

  Future<void> _loadFollowers() async {
    setState(() {
      _isLoadingFollowers = true;
      _followersError = null;
    });

    final result = await _repository.getFollowers(widget.userId);

    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _followersError = failure.message;
            _isLoadingFollowers = false;
          });
        }
      },
      (followers) {
        if (mounted) {
          setState(() {
            _followers = followers;
            _isLoadingFollowers = false;
          });
        }
      },
    );
  }

  Future<void> _loadFollowing() async {
    setState(() {
      _isLoadingFollowing = true;
      _followingError = null;
    });

    final result = await _repository.getFollowing(widget.userId);

    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _followingError = failure.message;
            _isLoadingFollowing = false;
          });
        }
      },
      (following) {
        if (mounted) {
          setState(() {
            _following = following;
            _isLoadingFollowing = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}님의 팔로우'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '팔로워'),
            Tab(text: '팔로잉'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowersList(),
          _buildFollowingList(),
        ],
      ),
    );
  }

  Widget _buildFollowersList() {
    if (_isLoadingFollowers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_followersError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.w, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(_followersError!, style: TextStyle(fontSize: 14.sp)),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: _loadFollowers,
              icon: const Icon(Icons.refresh),
              label: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        ),
      );
    }

    if (_followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64.w, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              '아직 팔로워가 없습니다',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _followers.length,
      itemBuilder: (context, index) {
        final follow = _followers[index];
        return UserListTile(
          userId: follow.followerId,
          userName: follow.followerName,
          onTap: () {
            // 사용자 프로필로 이동
            Navigator.pushNamed(
              context,
              '/user-profile',
              arguments: follow.followerId,
            );
          },
        );
      },
    );
  }

  Widget _buildFollowingList() {
    if (_isLoadingFollowing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_followingError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.w, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(_followingError!, style: TextStyle(fontSize: 14.sp)),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: _loadFollowing,
              icon: const Icon(Icons.refresh),
              label: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        ),
      );
    }

    if (_following.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_outlined, size: 64.w, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              '아직 팔로잉이 없습니다',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _following.length,
      itemBuilder: (context, index) {
        final follow = _following[index];
        return UserListTile(
          userId: follow.followingId,
          userName: follow.followingName,
          onTap: () {
            // 사용자 프로필로 이동
            Navigator.pushNamed(
              context,
              '/user-profile',
              arguments: follow.followingId,
            );
          },
        );
      },
    );
  }
}
