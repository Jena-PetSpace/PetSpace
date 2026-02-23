import 'package:flutter/material.dart';

class EmotionLoadingWidget extends StatefulWidget {
  final String message;

  const EmotionLoadingWidget({
    super.key,
    this.message = 'AI가 감정을 분석 중입니다...',
  });

  @override
  State<EmotionLoadingWidget> createState() => _EmotionLoadingWidgetState();
}

class _EmotionLoadingWidgetState extends State<EmotionLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  int _currentMessageIndex = 0;
  final List<String> _messages = [
    'AI가 감정을 분석 중입니다...',
    '표정을 읽고 있어요...',
    '감정 점수를 계산 중...',
    '거의 다 됐어요!',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // 메시지 순환
    Future.delayed(const Duration(seconds: 2), _cycleMessages);
  }

  void _cycleMessages() {
    if (!mounted) return;
    setState(() {
      _currentMessageIndex = (_currentMessageIndex + 1) % _messages.length;
    });
    Future.delayed(const Duration(seconds: 2), _cycleMessages);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotateAnimation.value * 3.14159,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            _messages[_currentMessageIndex],
            key: ValueKey<int>(_currentMessageIndex),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        const LinearProgressIndicator(),
        const SizedBox(height: 16),
        const Text(
          '잠시만 기다려주세요',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
