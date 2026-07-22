import 'package:flutter/material.dart';

import '../../../../shared/themes/app_theme.dart';

class SocialLoginButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final bool isLoading;
  final VoidCallback? onPressed;

  const SocialLoginButton({
    super.key,
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = !isLoading && onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Semantics(
        label: isLoading ? '$text 진행 중' : text,
        button: true,
        enabled: isEnabled,
        onTap: isEnabled ? onPressed : null,
        child: ExcludeSemantics(
          child: ElevatedButton(
            onPressed: isEnabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: textColor,
              disabledBackgroundColor: backgroundColor.withValues(alpha: 0.72),
              disabledForegroundColor: textColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                side: borderColor != null
                    ? BorderSide(color: borderColor!, width: 1)
                    : BorderSide.none,
              ),
            ),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '연결 중...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 22, color: textColor),
                      const SizedBox(width: 12),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
