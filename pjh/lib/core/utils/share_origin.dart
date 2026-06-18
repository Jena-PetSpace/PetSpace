import 'package:flutter/widgets.dart';

/// iPad에서 공유 시트(UIActivityViewController)는 popover로 표시되며,
/// anchor Rect(`sharePositionOrigin` / `Printing.sharePdf`의 `bounds`)를
/// 지정하지 않으면 iPadOS에서 크래시한다(share_plus #1640 / #3338).
/// 호출 위젯의 화면상 Rect를 anchor로 계산해 제공한다.
/// RenderBox를 구하지 못하면 화면 중앙의 1px Rect로 폴백한다(크래시 방지 최우선).
Rect shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  final size = MediaQuery.maybeOf(context)?.size ?? const Size(400, 800);
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}
