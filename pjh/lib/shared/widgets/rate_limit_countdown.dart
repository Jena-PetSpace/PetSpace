import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RateLimitCountdown extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onComplete;

  const RateLimitCountdown({
    super.key,
    required this.duration,
    this.onComplete,
  });

  @override
  State<RateLimitCountdown> createState() => _RateLimitCountdownState();
}

class _RateLimitCountdownState extends State<RateLimitCountdown> {
  late Duration _remainingTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.duration;
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        widget.onComplete?.call();
      } else {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: Colors.orange.shade700,
            size: 24.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '인증 이메일 전송 제한',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${_formatDuration(_remainingTime)} 후 다시 시도 가능',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatDuration(_remainingTime),
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
