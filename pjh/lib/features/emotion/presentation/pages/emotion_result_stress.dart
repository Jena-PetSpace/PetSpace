part of 'emotion_result_page.dart';

  Widget _buildStressCard() {
    final stress = widget.analysis.emotions.stressLevel;
    final stressColor = stress >= 70
        ? const Color(0xFFE74C3C)
        : stress >= 40
            ? const Color(0xFFF39C12)
            : const Color(0xFF2ECC71);
    final stressLabel = stress >= 70
        ? '높음'
        : stress >= 40
            ? '보통'
            : '낮음';
    final stressDesc = stress >= 70
        ? '스트레스가 높은 상태예요. 편안한 환경과 충분한 휴식이 필요합니다.'
        : stress >= 40
            ? '약간의 긴장 상태예요. 부드러운 스킨십으로 안정시켜 주세요.'
            : '안정적인 상태예요. 지금처럼 편안한 환경을 유지해 주세요.';

    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '스트레스 지수',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: stressColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  stressLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: stressColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$stress',
                style: TextStyle(
                  fontSize: 42.sp,
                  fontWeight: FontWeight.bold,
                  color: stressColor,
                  height: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 6.h, left: 2.w),
                child: Text(
                  '/ 100',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: stress / 100,
              minHeight: 8.h,
              backgroundColor: Colors.grey.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(stressColor),
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: stressColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14.w, color: stressColor),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    stressDesc,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          // 더보기 토글 버튼
          InkWell(
            onTap: () => setState(() => _showStressDetail = !_showStressDetail),
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showStressDetail
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16.w,
                    color: AppTheme.primaryColor,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _showStressDetail ? '접기' : '관련 분석 더보기',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 더보기 콘텐츠
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showStressDetail
                ? _buildStressDetailContent(stress, stressColor)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStressDetailContent(int stress, Color stressColor) {
    final emotions = widget.analysis.emotions;

    // 스트레스 관련 분석
    final analysisItems = <String>[];

    // 감정별 스트레스 영향 분석
    if (emotions.anxiety > 0.3) {
      analysisItems.add('불안 수치가 ${(emotions.anxiety * 100).toInt()}%로 다소 높아 스트레스에 영향을 줄 수 있어요.');
    }
    if (emotions.sadness > 0.3) {
      analysisItems.add('슬픔 수치가 ${(emotions.sadness * 100).toInt()}%로 감정적 피로가 누적되었을 수 있어요.');
    }
    if (emotions.happiness < 0.2) {
      analysisItems.add('기쁨 수치가 낮아 전반적인 기분 개선이 필요해 보여요.');
    }
    if (emotions.sleepiness > 0.4) {
      analysisItems.add('졸림 수치가 높아 수면 부족이나 체력 저하가 의심돼요.');
    }

    // 감정 조합 기반 심층 분석
    if (emotions.anxiety > 0.3 && emotions.sadness > 0.3) {
      analysisItems.add('불안과 슬픔이 동시에 높아요. 분리불안이나 환경 변화로 인한 복합 스트레스일 수 있어요.');
    }
    if (emotions.anxiety > 0.3 && emotions.curiosity > 0.3) {
      analysisItems.add('불안 속에서도 호기심이 있어요. 새로운 환경에 대한 경계와 탐구가 공존하는 상태예요.');
    }
    if (emotions.sleepiness > 0.3 && emotions.sadness > 0.2) {
      analysisItems.add('졸림과 슬픔이 함께 나타나요. 무기력함이나 우울 경향을 주의 깊게 관찰해 주세요.');
    }
    if (emotions.happiness > 0.5 && stress >= 40) {
      analysisItems.add('기쁨은 높지만 스트레스도 있어요. 흥분 상태로 인한 과각성일 수 있어요.');
    }

    // 스트레스 수준별 종합 판단
    if (stress >= 80) {
      analysisItems.add('스트레스 수치가 매우 높아 즉각적인 안정 조치가 필요해요.');
    } else if (stress >= 60) {
      analysisItems.add('스트레스가 경계 수준이에요. 지속되면 건강에 영향을 줄 수 있어요.');
    } else if (stress <= 20) {
      analysisItems.add('스트레스가 매우 낮아 매우 안정적인 상태예요.');
    }

    // 감정 균형도 분석
    final emotionValues = [
      emotions.happiness, emotions.sadness, emotions.anxiety,
      emotions.sleepiness, emotions.curiosity,
    ];
    final maxEmotion = emotionValues.reduce((a, b) => a > b ? a : b);
    final minEmotion = emotionValues.reduce((a, b) => a < b ? a : b);
    if (maxEmotion - minEmotion > 0.5) {
      analysisItems.add('감정 편차가 커요. 특정 감정에 크게 치우친 상태로 보여요.');
    } else if (maxEmotion - minEmotion < 0.15 && stress < 40) {
      analysisItems.add('감정이 고르게 분포되어 있어 심리적으로 균형 잡힌 상태예요.');
    }

    if (analysisItems.isEmpty) {
      analysisItems.add('현재 감정 상태가 비교적 안정적이에요.');
    }

    // 스트레스 수준별 행동 요령
    final tips = stress >= 70
        ? [
            '조용하고 안전한 공간으로 이동시켜 주세요',
            '과도한 자극(소음, 낯선 사람)을 줄여주세요',
            '좋아하는 간식이나 장난감으로 기분 전환을 시도하세요',
            '부드럽게 쓰다듬어 안정감을 줘주세요',
            '일시적으로 다른 동물과의 접촉을 줄여주세요',
            '차분한 목소리로 이름을 불러 안심시켜 주세요',
            '증상이 지속되면 수의사 상담을 권장합니다',
          ]
        : stress >= 40
            ? [
                '규칙적인 산책과 운동으로 에너지를 발산시켜 주세요',
                '편안한 음악이나 조명으로 환경을 안정시켜 주세요',
                '일상 루틴을 유지해 안정감을 줘주세요',
                '스킨십 시간을 늘려주세요',
                '좋아하는 놀이를 통해 긍정적 경험을 쌓아주세요',
                '충분한 수면 환경을 제공해 주세요',
              ]
            : [
                '현재 환경이 잘 맞는 것 같아요. 유지해 주세요',
                '규칙적인 식사와 산책을 계속 이어가세요',
                '긍정적인 상호작용을 꾸준히 해주세요',
                '새로운 놀이나 간식으로 즐거운 자극을 줘보세요',
                '다른 반려동물이나 사람과의 사회화도 좋아요',
              ];

    // 간식/음식 추천
    final foodTips = stress >= 70
        ? [
            '캐모마일 성분이 든 진정 간식을 줘보세요',
            '따뜻한 물에 적신 사료로 식사를 편안하게 해주세요',
            '트립토판이 풍부한 닭가슴살 간식이 안정에 도움돼요',
          ]
        : stress >= 40
            ? [
                '호박, 고구마 등 소화가 편한 간식을 줘보세요',
                '오메가3가 풍부한 연어 간식이 기분 개선에 좋아요',
                '블루베리 등 항산화 과일 간식도 추천해요',
              ]
            : [
                '좋아하는 간식으로 긍정적 보상을 해주세요',
                '수분 보충이 되는 수박, 오이 간식도 좋아요',
                '노즈워크 간식으로 두뇌 자극을 줘보세요',
              ];

    // 환경/생활 추천
    final lifeTips = stress >= 70
        ? [
            '조명을 어둡게 하고 조용한 음악을 틀어주세요',
            '익숙한 냄새가 나는 담요나 옷을 곁에 두세요',
          ]
        : stress >= 40
            ? [
                '하루 2회 이상 짧은 산책을 해보세요',
                '놀이 시간을 정해서 루틴을 만들어 주세요',
              ]
            : [
                '새로운 산책 코스를 시도해 보세요',
                '다양한 질감의 장난감으로 자극을 줘보세요',
              ];

    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 상태 분석
          _buildStressSection(
            title: '상태 분석',
            icon: Icons.analytics_outlined,
            color: stressColor,
            items: analysisItems,
          ),
          SizedBox(height: 12.h),
          // 2. 행동 요령
          _buildStressSection(
            title: '행동 요령',
            icon: Icons.directions_walk_outlined,
            color: const Color(0xFF3498DB),
            items: tips,
          ),
          SizedBox(height: 12.h),
          // 3. 간식/음식 추천
          _buildStressSection(
            title: '간식/음식 추천',
            icon: Icons.restaurant_outlined,
            color: const Color(0xFFE67E22),
            items: foodTips,
          ),
          SizedBox(height: 12.h),
          // 4. 환경/생활 추천
          _buildStressSection(
            title: '환경/생활 추천',
            icon: Icons.home_outlined,
            color: const Color(0xFF27AE60),
            items: lifeTips,
          ),
        ],
      ),
    );
  }

  Widget _buildStressSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16.w, color: color),
              SizedBox(width: 6.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ...items.map((item) => Padding(
            padding: EdgeInsets.only(bottom: 5.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 6.h),
                  width: 4.w,
                  height: 4.w,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── 6. A-3: 건강 체크 알림 카드 ──
