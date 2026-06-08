import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_event.dart';
import 'pet_passport_card.dart';

/// 다견(여러 마리) 여권 카드 캐러셀.
///
/// - PageView 로 펫별 여권 카드 좌우 스와이프 + 하단 dots 인디케이터.
/// - 맨 끝에 "+ 새 여권 추가" 카드 → 등록 페이지.
/// - 페이지 전환 시 SelectPet 디스패치 → 앱 전역 selectedPet 과 동기화.
/// - 0마리 케이스는 호출부에서 빈 상태 CTA 로 처리(여기 진입 안 함).
class PetPassportCarousel extends StatefulWidget {
  final List<Pet> pets;

  /// 현재 선택된 펫(없으면 첫 번째). 초기 페이지 위치 결정.
  final Pet? selectedPet;

  /// 각 펫의 "오늘의 기분"(분포 1위). pet.id → mood. 없으면 미분석.
  final PassportMood? Function(Pet pet) moodFor;

  final VoidCallback onAddPassport;
  final void Function(Pet pet) onHealthTap;
  final void Function(Pet pet) onHistoryTap;
  final void Function(Pet pet) onAnalyzeTap;

  const PetPassportCarousel({
    super.key,
    required this.pets,
    required this.selectedPet,
    required this.moodFor,
    required this.onAddPassport,
    required this.onHealthTap,
    required this.onHistoryTap,
    required this.onAnalyzeTap,
  });

  @override
  State<PetPassportCarousel> createState() => _PetPassportCarouselState();
}

class _PetPassportCarouselState extends State<PetPassportCarousel> {
  late final PageController _controller;
  late int _currentPage;

  /// 측정 전 임시 높이(첫 프레임). 측정 후 실제 카드 높이로 대체된다.
  static const double _fallbackHeight = 320;

  /// 실제 카드 높이(첫 펫 카드를 한 번 측정). null 이면 측정 전.
  double? _measuredHeight;

  /// 측정용 키(화면 밖에 카드 1장 렌더해 높이만 잰다).
  final GlobalKey _measureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentPage = _initialIndex();
    _controller = PageController(initialPage: _currentPage, viewportFraction: 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final ctx = _measureKey.currentContext;
    if (ctx == null) return;
    final h = ctx.size?.height;
    if (h != null && h > 0 && (_measuredHeight == null || (h - _measuredHeight!).abs() > 0.5)) {
      setState(() => _measuredHeight = h);
    }
  }

  int _initialIndex() {
    final sel = widget.selectedPet;
    if (sel == null) return 0;
    final idx = widget.pets.indexWhere((p) => p.id == sel.id);
    return idx < 0 ? 0 : idx;
  }

  @override
  void didUpdateWidget(covariant PetPassportCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 펫 목록/선택이 외부에서 바뀌면 현재 페이지를 보정(범위 초과 방지).
    final maxIndex = widget.pets.length; // +추가 카드 포함 → length 가 마지막 인덱스
    if (_currentPage > maxIndex) {
      _currentPage = maxIndex;
      if (_controller.hasClients) {
        _controller.jumpToPage(_currentPage);
      }
    }
    // 데이터 변경으로 카드 높이가 달라질 수 있으니 재측정.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    // 실제 펫 카드일 때만 selectedPet 동기화("+추가" 카드는 제외).
    if (index < widget.pets.length) {
      context.read<PetBloc>().add(SelectPet(widget.pets[index]));
    }
  }

  PetPassportCard _cardFor(Pet pet) => PetPassportCard(
        pet: pet,
        mood: widget.moodFor(pet),
        onHealthTap: () => widget.onHealthTap(pet),
        onHistoryTap: () => widget.onHistoryTap(pet),
        onAnalyzeTap: () => widget.onAnalyzeTap(pet),
      );

  @override
  Widget build(BuildContext context) {
    // 펫 카드 N개 + "추가" 카드 1개
    final pageCount = widget.pets.length + 1;
    // 측정된 카드 높이가 있으면 그 높이로(여백 없음), 없으면 임시 높이.
    final pageHeight = _measuredHeight ?? _fallbackHeight.h;

    return Stack(
      children: [
        Column(
          children: [
            SizedBox(
              height: pageHeight,
              child: PageView.builder(
                controller: _controller,
                onPageChanged: _onPageChanged,
                itemCount: pageCount,
                itemBuilder: (context, index) {
                  if (index == widget.pets.length) {
                    return _buildAddCard();
                  }
                  return _cardFor(widget.pets[index]);
                },
              ),
            ),
            SizedBox(height: 10.h),
            _buildDots(pageCount),
          ],
        ),
        // 화면 밖(완전 투명)에서 첫 펫 카드 1장을 렌더해 높이만 측정.
        if (widget.pets.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: -10000,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0,
                child: Container(
                  key: _measureKey,
                  child: _cardFor(widget.pets.first),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── "+ 새 여권 추가" 카드 ──────────────────────────────────
  Widget _buildAddCard() {
    return GestureDetector(
      onTap: widget.onAddPassport,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: const BoxDecoration(
                  color: PetPassportCard.coral,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: Colors.white, size: 28.w),
              ),
              SizedBox(height: 12.h),
              Text(
                '새 여권 추가',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '반려동물을 더 등록해보세요',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 페이지 인디케이터(dots) ────────────────────────────────
  Widget _buildDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == _currentPage;
        final isAddDot = i == count - 1; // 마지막 = 추가 카드 dot
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 3.w),
          width: isActive ? 18.w : 7.w,
          height: 7.w,
          decoration: BoxDecoration(
            color: isActive
                ? (isAddDot
                    ? PetPassportCard.coral
                    : Colors.white)
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4.r),
          ),
        );
      }),
    );
  }
}
