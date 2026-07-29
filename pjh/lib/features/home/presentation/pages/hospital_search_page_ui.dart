part of 'hospital_search_page.dart';

extension _HospitalUI on _HospitalSearchPageState {
  Widget _buildMapOverlayButtons() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ValueListenableBuilder<double>(
            valueListenable: _sheetExtent,
            builder: (context, extent, child) {
              if (extent >= kPlaceSheetMax - 0.04) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: EdgeInsets.only(
                  right: 12.w,
                  bottom: constraints.maxHeight * extent + 12.h,
                ),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildOverlayIconButton(
                        semanticsLabel: '현재 위치로 이동',
                        icon: _isFollowingLocation
                            ? Icons.my_location
                            : Icons.location_searching,
                        color: _isFollowingLocation
                            ? AppTheme.primaryColor
                            : AppTheme.neutral600,
                        onTap: _moveToMyLocation,
                      ),
                      SizedBox(height: 8.h),
                      ..._buildRadiusButtons(),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCloseMapButton() {
    return Positioned(
      top: 12.h,
      right: 12.w,
      child: Semantics(
        label: '장소 화면 닫기',
        button: true,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _closePlaceScreen,
            child: SizedBox(
              width: 44.w,
              height: 44.w,
              child: Icon(
                Icons.close,
                size: 22.w,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRadiusButtons() {
    return List.generate(_radii.length, (i) {
      final selected = _selectedRadiusIndex == i;
      return Padding(
        padding: EdgeInsets.only(bottom: i < _radii.length - 1 ? 4.h : 0),
        child: Semantics(
          label: '검색 반경 ${_radiiLabel[i]}',
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: () async {
              if (_selectedRadiusIndex == i) return;
              setState(() => _selectedRadiusIndex = i);
              if (_mapReady) {
                await _moveCameraProgrammatically(
                  target: LatLng(
                    latitude: _searchOrigin.latitude,
                    longitude: _searchOrigin.longitude,
                  ),
                  zoomLevel: _radiusZoomLevels[i],
                );
              }
              final manualKeyword = _manualSearchKeyword;
              if (manualKeyword == null) {
                await _searchCategory(_selectedCategory);
              } else {
                await _searchByKeyword(manualKeyword);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 44.w,
              height: 32.h,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _radiiLabel[i],
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppTheme.secondaryTextColor,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildOverlayIconButton(
      {required String semanticsLabel,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Icon(icon, size: 22.w, color: color),
        ),
      ),
    );
  }

  Widget _buildSearchingIndicator() {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  width: 14.w,
                  height: 14.w,
                  child: const CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryColor)),
              SizedBox(width: 10.w),
              Text('검색 중...',
                  style:
                      TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildReSearchButton() {
    return Positioned(
      top: 12,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _reSearchHere,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh, size: 14.w, color: Colors.white),
              SizedBox(width: 6.w),
              Text('이 지역 재검색',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final estimatedHeaderHeight =
              (68.h + ((textScale - 1).clamp(0.0, 1.0) * 16.h));
          const maxAllowedMin = kPlaceSheetMax - 0.08;
          final effectiveMin = (estimatedHeaderHeight / constraints.maxHeight)
              .clamp(kPlaceSheetMin, maxAllowedMin)
              .toDouble();
          final effectiveInitial = effectiveMin > kPlaceSheetInitial
              ? effectiveMin
              : kPlaceSheetInitial;
          final snapSizes = <double>[effectiveMin];
          if ((effectiveInitial - effectiveMin).abs() > 0.001) {
            snapSizes.add(effectiveInitial);
          }
          if ((kPlaceSheetMax - snapSizes.last).abs() > 0.001) {
            snapSizes.add(kPlaceSheetMax);
          }
          _effectiveSheetMin = effectiveMin;
          _effectiveSheetInitial = effectiveInitial;
          _scheduleSheetAttachSync();

          return DraggableScrollableSheet(
            controller: _sheetController,
            minChildSize: effectiveMin,
            initialChildSize: effectiveInitial,
            maxChildSize: kPlaceSheetMax,
            snap: true,
            snapSizes: snapSizes,
            shouldCloseOnMinExtent: false,
            builder: (context, sheetScrollController) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20.r)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20.r)),
                  child: CustomScrollView(
                    controller: sheetScrollController,
                    physics: const ClampingScrollPhysics(),
                    slivers: _showDetail && _selectedPlace != null
                        ? _buildDetailSlivers(_selectedPlace!)
                        : _buildListSlivers(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildListSlivers() {
    return <Widget>[
      SliverToBoxAdapter(child: _buildSheetHeader()),
      if (_places.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(),
        )
      else
        SliverPadding(
          padding:
              EdgeInsets.only(left: 12.w, right: 12.w, top: 4.h, bottom: 20.h),
          sliver: SliverList.separated(
            itemCount: _places.length,
            separatorBuilder: (_, __) => SizedBox(height: 6.h),
            itemBuilder: (_, index) => _buildPlaceItem(
              _places[index],
              placeOrdinal(index),
            ),
          ),
        ),
    ];
  }

  Widget _buildSheetHeader() {
    return Semantics(
      label: '장소 결과 시트',
      button: true,
      child: InkWell(
        onTap: () {
          final next = switch (_sheetSize) {
            _SheetSize.collapsed => _SheetSize.half,
            _SheetSize.half => _SheetSize.full,
            _SheetSize.full => _SheetSize.half,
          };
          _sheetSize = next;
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 64.h),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 12.w, 8.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppTheme.neutral500.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _searching && _places.isEmpty
                            ? '$_resultHeaderLabel 검색 중...'
                            : '$_resultHeaderLabel ${_places.length}개',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                    ),
                    if (_places.any((place) => place.distanceM != null)) ...[
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          _distanceOriginLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(width: 8.w),
                    ValueListenableBuilder<double>(
                      valueListenable: _sheetExtent,
                      builder: (context, extent, child) {
                        return Container(
                          width: 28.w,
                          height: 28.w,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            extent >= kPlaceSheetMax - 0.04
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            size: 18.w,
                            color: AppTheme.primaryColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailSlivers(HospitalPlace place) {
    return <Widget>[
      SliverToBoxAdapter(child: _buildDetailContent(place)),
      SliverToBoxAdapter(child: SizedBox(height: 20.h)),
    ];
  }

  Widget _buildDetailContent(HospitalPlace place) {
    final isFav = _isFavorite(place.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 0),
          child: Row(
            children: [
              Semantics(
                label: '장소 목록으로',
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12.r),
                  onTap: _closeDetail,
                  child: SizedBox(
                    height: 44.h,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Row(
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 20.w,
                            color: AppTheme.secondaryTextColor,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            '목록으로',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(place.name,
                  style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryTextColor)),
            ),
            if (place.distanceM != null) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(_formatDistance(place.distanceM!),
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor)),
              ),
            ],
          ]),
        ),
        SizedBox(height: 4.h),
        if (place.category.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(place.category.split('>').last.trim(),
                  style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        SizedBox(height: 8.h),
        if (place.address.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.location_on_outlined,
                  size: 15.w, color: AppTheme.secondaryTextColor),
              SizedBox(width: 5.w),
              Expanded(
                  child: Text(place.address,
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.secondaryTextColor,
                          height: 1.4))),
            ]),
          ),
        if (place.phone.isNotEmpty) ...[
          SizedBox(height: 3.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(children: [
              Icon(Icons.phone_outlined,
                  size: 15.w, color: AppTheme.secondaryTextColor),
              SizedBox(width: 5.w),
              Text(place.phone,
                  style: TextStyle(
                      fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
            ]),
          ),
        ],
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: _buildPrimaryActionButton(
            semanticsLabel: '${place.name} 길찾기',
            icon: Icons.near_me,
            label: '길찾기',
            onTap: () => _openKakaoMapDirections(place),
          ),
        ),
        SizedBox(height: 10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: _buildSecondaryActions(place, isFav),
        ),
      ],
    );
  }

  Widget _buildPrimaryActionButton({
    required String semanticsLabel,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: onTap,
          child: SizedBox(
            height: 52.h,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19.w, color: Colors.white),
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActions(HospitalPlace place, bool isFav) {
    final actions = <({String label, IconData icon, VoidCallback onTap})>[
      if (place.phone.isNotEmpty)
        (
          label: '전화',
          icon: Icons.phone_outlined,
          onTap: () => _callPhone(place.phone),
        ),
      (
        label: isFav ? '저장 취소' : '저장',
        icon: isFav ? Icons.bookmark : Icons.bookmark_border,
        onTap: () => _toggleFavorite(place),
      ),
      (
        label: '공유',
        icon: Icons.share_outlined,
        onTap: () => _sharePlace(place),
      ),
      (
        label: '상세',
        icon: Icons.open_in_new,
        onTap: () => _openKakaoMapDetail(place),
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) SizedBox(width: 6.w),
          Expanded(
            child: _buildCompactActionButton(
              label: actions[index].label,
              icon: actions[index].icon,
              onTap: actions[index].onTap,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: onTap,
          child: SizedBox(
            height: 62.h,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19.w, color: AppTheme.primaryColor),
                  SizedBox(height: 4.h),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 6.h),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: _searchByKeyword,
          decoration: InputDecoration(
            hintText: '병원, 시설 이름으로 검색',
            hintStyle:
                TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor),
            prefixIcon: Icon(Icons.search,
                size: 20.w, color: AppTheme.secondaryTextColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18.w),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide:
                  const BorderSide(color: AppTheme.neutral200, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide:
                  const BorderSide(color: AppTheme.neutral200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide:
                  const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildLocationBanner() {
    if (_locationState == _LocationAccessState.checking ||
        _locationState == _LocationAccessState.ready) {
      return const SizedBox.shrink();
    }
    final isNeutral = _locationState == _LocationAccessState.denied;
    final message = switch (_locationState) {
      _LocationAccessState.denied => '내 주변 장소를 보려면 위치 권한이 필요해요.',
      _LocationAccessState.deniedForever => '설정에서 위치 권한을 허용해주세요.',
      _LocationAccessState.serviceDisabled => '현재 위치를 사용하려면 위치 서비스를 켜주세요.',
      _ => '현재 위치를 확인할 수 없어 서울시청 주변을 보여드려요.',
    };
    final action = switch (_locationState) {
      _LocationAccessState.denied => '위치 권한 허용',
      _LocationAccessState.deniedForever ||
      _LocationAccessState.serviceDisabled =>
        '설정 열기',
      _ => '다시 시도',
    };
    final foreground = isNeutral ? AppTheme.primaryColor : AppTheme.errorColor;
    return Container(
      color: isNeutral
          ? AppTheme.primaryColor.withValues(alpha: 0.08)
          : AppTheme.tilePastelRose,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(children: [
        Icon(
          isNeutral ? Icons.location_on_outlined : Icons.location_off,
          size: 16.w,
          color: foreground,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 11.sp, color: foreground),
          ),
        ),
        SizedBox(width: 8.w),
        Flexible(
          child: GestureDetector(
            onTap: _handleLocationAction,
            child: Text(
              action,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11.sp,
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCategoryBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(0, 0, 0, 10.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          children: List.generate(_categories.length, (i) {
            final cat = _categories[i];
            final selected = _selectedCategory == i;
            return GestureDetector(
              onTap: () => _searchCategory(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color:
                        selected ? AppTheme.primaryColor : AppTheme.neutral300,
                    width: 1.5,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2)),
                        ]
                      : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset(cat.iconAsset,
                      width: 18.w,
                      height: 18.w,
                      color: selected ? Colors.white : null),
                  SizedBox(width: 5.w),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color:
                          selected ? Colors.white : AppTheme.primaryTextColor,
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPlaceItem(HospitalPlace place, int index) {
    final isSelected = _selectedPlace?.id == place.id;
    final isFav = _isFavorite(place.id);
    return Semantics(
      label: '$index번 ${place.name}',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => _selectPlace(place),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : AppTheme.neutral500.withValues(alpha: 0.12),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1))
            ],
          ),
          child: Row(children: [
            Container(
              width: 26.w,
              height: 26.w,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text('$index',
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected ? Colors.white : AppTheme.primaryColor)),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name,
                        style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryTextColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (place.category.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        place.category.split('>').last.trim(),
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 2.h),
                    if (place.address.isNotEmpty)
                      Text(place.address,
                          style: TextStyle(
                              fontSize: 10.sp,
                              color: AppTheme.secondaryTextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ]),
            ),
            Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (place.distanceM != null)
                    Text(_formatDistance(place.distanceM!),
                        style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor)),
                  SizedBox(height: 2.h),
                  Semantics(
                    label: isFav ? '저장 취소' : '장소 저장',
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggleFavorite(place),
                      child: SizedBox(
                        width: 44.w,
                        height: 44.w,
                        child: Icon(
                          isFav ? Icons.bookmark : Icons.bookmark_border,
                          size: 20.w,
                          color: isFav
                              ? AppTheme.primaryColor
                              : AppTheme.neutral400,
                        ),
                      ),
                    ),
                  ),
                ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searching) return const SizedBox.shrink();
    if (_categories[_selectedCategory].isFavoriteTab) {
      final hasLegacy = _hasUnresolvedLegacyPlaces;
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
            hasLegacy ? '기존에 저장한 장소를 다시 찾고 있어요.' : '저장한 장소가 없어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            hasLegacy ? '카테고리에서 장소를 다시 검색하면 복원됩니다.' : '자주 찾는 장소를 저장해보세요.',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ]),
      );
    }
    if (_searchUiState != _PlaceSearchUiState.idle &&
        _searchUiState != _PlaceSearchUiState.empty) {
      return Center(
        child: Text(
          _messageForSearchState(_searchUiState),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.sp,
            color: AppTheme.secondaryTextColor,
          ),
        ),
      );
    }
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(
          _manualSearchKeyword == null
              ? '${_radiiLabel[_selectedRadiusIndex]} 이내에\n'
                  '${_categories[_selectedCategory].label}이 없어요'
              : '“$_manualSearchKeyword” 검색 결과가 없어요',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryTextColor),
        ),
        SizedBox(height: 6.h),
        Text('반경을 넓히거나 다른 지역을 검색해보세요',
            style:
                TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
      ]),
    );
  }

  String get _distanceOriginLabel =>
      placeDistanceOriginLabel(_searchOrigin.type);

  String get _resultHeaderLabel {
    if (_categories[_selectedCategory].isFavoriteTab) {
      return _categories[_selectedCategory].label;
    }
    final hasAppliedResults = _searchResults.isNotEmpty;
    final keyword =
        hasAppliedResults ? _resultManualSearchKeyword : _manualSearchKeyword;
    final categoryIndex =
        hasAppliedResults ? _resultCategory : _selectedCategory;
    return keyword == null
        ? _categories[categoryIndex].label
        : '“$keyword” 검색 결과';
  }
}
