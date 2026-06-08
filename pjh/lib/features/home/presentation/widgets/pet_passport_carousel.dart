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

  /// 카드 높이(밝은 여권 카드 내용 + 약간의 버퍼). 844 baseline 기준.
  /// 사진 확대(116x142) + 하단 행 반영해 여유 확보(실기기 오버플로 방지).
  static const double _carouselHeight = 312;

  @override
  void initState() {
    super.initState();
    _currentPage = _initialIndex();
    _controller = PageController(initialPage: _currentPage, viewportFraction: 1);
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

  @override
  Widget build(BuildContext context) {
    // 펫 카드 N개 + "추가" 카드 1개
    final pageCount = widget.pets.length + 1;

    return Column(
      children: [
        SizedBox(
          height: _carouselHeight.h,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: _onPageChanged,
            itemCount: pageCount,
            itemBuilder: (context, index) {
              if (index == widget.pets.length) {
                return _buildAddCard();
              }
              final pet = widget.pets[index];
              return PetPassportCard(
                pet: pet,
                mood: widget.moodFor(pet),
                onHealthTap: () => widget.onHealthTap(pet),
                onHistoryTap: () => widget.onHistoryTap(pet),
                onAnalyzeTap: () => widget.onAnalyzeTap(pet),
              );
            },
          ),
        ),
        SizedBox(height: 10.h),
        _buildDots(pageCount),
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
