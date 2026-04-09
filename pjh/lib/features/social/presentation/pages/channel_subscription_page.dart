import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/themes/app_theme.dart';

class ChannelSubscriptionPage extends StatefulWidget {
  const ChannelSubscriptionPage({super.key});

  @override
  State<ChannelSubscriptionPage> createState() => _ChannelSubscriptionPageState();
}

class _ChannelSubscriptionPageState extends State<ChannelSubscriptionPage> {
  static const _channels = [
    _Channel(tag: 'health', emoji: '💊', label: '건강', desc: '예방접종, 질병, 영양 정보'),
    _Channel(tag: 'training', emoji: '🎯', label: '훈련', desc: '기본 훈련, 문제행동 교정'),
    _Channel(tag: 'magazine', emoji: '📰', label: '매거진', desc: '전문가 칼럼, 라이프스타일'),
    _Channel(tag: 'qa', emoji: '❓', label: 'Q&A', desc: '궁금증 해결, 경험 나눔'),
    _Channel(tag: 'dog', emoji: '🐕', label: '강아지', desc: '강아지 전용 커뮤니티'),
    _Channel(tag: 'cat', emoji: '🐈', label: '고양이', desc: '고양이 전용 커뮤니티'),
    _Channel(tag: 'food', emoji: '🥩', label: '사료/간식', desc: '먹거리 정보 공유'),
    _Channel(tag: 'hot', emoji: '🔥', label: 'HOT', desc: '지금 가장 인기 있는 글'),
  ];

  Set<String> _subscribed = {};

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('channel_subscriptions') ?? ['health', 'hot'];
    if (mounted) setState(() => _subscribed = Set<String>.from(list));
  }

  Future<void> _toggle(String tag) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_subscribed.contains(tag)) {
        _subscribed.remove(tag);
      } else {
        _subscribed.add(tag);
      }
    });
    await prefs.setStringList('channel_subscriptions', _subscribed.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('채널 구독', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryTextColor,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('완료', style: TextStyle(color: AppTheme.primaryColor, fontSize: 14.sp, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            color: Colors.white,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('관심 채널을 선택하면\n피드에 맞춤 콘텐츠가 우선 노출돼요',
                style: TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor, height: 1.5)),
              SizedBox(height: 8.h),
              Text('${_subscribed.length}개 채널 구독 중',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(16.w),
              itemCount: _channels.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (_, i) {
                final ch = _channels[i];
                final sub = _subscribed.contains(ch.tag);
                return GestureDetector(
                  onTap: () => _toggle(ch.tag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: sub ? AppTheme.primaryColor.withValues(alpha: 0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: sub ? AppTheme.primaryColor : AppTheme.dividerColor, width: 1.5),
                    ),
                    child: Row(children: [
                      Text(ch.emoji, style: TextStyle(fontSize: 26.sp)),
                      SizedBox(width: 14.w),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ch.label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700,
                          color: sub ? AppTheme.primaryColor : AppTheme.primaryTextColor)),
                        Text(ch.desc, style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor)),
                      ])),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 26.w, height: 26.w,
                        decoration: BoxDecoration(
                          color: sub ? AppTheme.primaryColor : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: sub ? AppTheme.primaryColor : AppTheme.dividerColor, width: 2),
                        ),
                        child: sub ? Icon(Icons.check, size: 14.w, color: Colors.white) : null,
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Channel {
  final String tag, emoji, label, desc;
  const _Channel({required this.tag, required this.emoji, required this.label, required this.desc});
}
