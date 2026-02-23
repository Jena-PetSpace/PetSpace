import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

typedef LazyLoadCallback = Future<List<T>> Function<T>();
typedef ItemBuilder<T> = Widget Function(BuildContext context, T item, int index);

class LazyLoadList<T> extends StatefulWidget {
  final Future<List<T>> Function() onLoadInitial;
  final Future<List<T>> Function() onLoadMore;
  final ItemBuilder<T> itemBuilder;
  final Widget? separator;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final int loadThreshold;
  final bool enablePullToRefresh;

  const LazyLoadList({
    super.key,
    required this.onLoadInitial,
    required this.onLoadMore,
    required this.itemBuilder,
    this.separator,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.padding,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
    this.loadThreshold = 3,
    this.enablePullToRefresh = true,
  });

  @override
  State<LazyLoadList<T>> createState() => _LazyLoadListState<T>();
}

class _LazyLoadListState<T> extends State<LazyLoadList<T>> {
  final List<T> _items = [];
  late ScrollController _scrollController;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _hasMore = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - (widget.loadThreshold * 100)) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final newItems = await widget.onLoadInitial();
      setState(() {
        _items.clear();
        _items.addAll(newItems);
        _hasMore = newItems.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMore || _hasError) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newItems = await widget.onLoadMore();
      setState(() {
        _items.addAll(newItems);
        _hasMore = newItems.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('더 많은 데이터를 불러오는 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return widget.loadingWidget ?? _buildDefaultLoadingWidget();
    }

    if (_hasError && _items.isEmpty) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    if (_items.isEmpty) {
      return widget.emptyWidget ?? _buildDefaultEmptyWidget();
    }

    Widget listView = _buildListView();

    if (widget.enablePullToRefresh) {
      listView = RefreshIndicator(
        onRefresh: _onRefresh,
        child: listView,
      );
    }

    return listView;
  }

  Widget _buildListView() {
    return ListView.separated(
      controller: _scrollController,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) {
        if (index >= _items.length) {
          return const SizedBox.shrink();
        }
        return widget.separator ?? const SizedBox.shrink();
      },
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return _buildLoadMoreIndicator();
        }

        return widget.itemBuilder(context, _items[index], index);
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (_isLoadingMore) {
      return Padding(
        padding: EdgeInsets.all(16.w),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasMore) {
      return Padding(
        padding: EdgeInsets.all(16.w),
        child: Center(
          child: Text(
            '모든 항목을 불러왔습니다',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14.sp,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDefaultLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: 16.h),
          Text('로딩 중...', style: TextStyle(fontSize: 14.sp)),
        ],
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.w,
            color: Colors.red,
          ),
          SizedBox(height: 16.h),
          Text(
            '데이터를 불러오는 중 오류가 발생했습니다',
            style: TextStyle(fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadInitialData,
            child: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64.w,
            color: Colors.grey,
          ),
          SizedBox(height: 16.h),
          Text(
            '표시할 항목이 없습니다',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // Public methods
  void refresh() {
    _loadInitialData();
  }

  void loadMore() {
    _loadMoreData();
  }

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasError => _hasError;
  bool get hasMore => _hasMore;
}

// Specialized version for posts
class LazyPostsList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> Function() onLoadInitial;
  final Future<List<Map<String, dynamic>>> Function() onLoadMore;
  final Widget Function(BuildContext, Map<String, dynamic>, int) postBuilder;

  const LazyPostsList({
    super.key,
    required this.onLoadInitial,
    required this.onLoadMore,
    required this.postBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LazyLoadList<Map<String, dynamic>>(
      onLoadInitial: onLoadInitial,
      onLoadMore: onLoadMore,
      itemBuilder: postBuilder,
      separator: SizedBox(height: 16.h),
      padding: EdgeInsets.all(16.w),
      enablePullToRefresh: true,
      loadThreshold: 5,
    );
  }
}

// Specialized version for comments
class LazyCommentsList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> Function() onLoadInitial;
  final Future<List<Map<String, dynamic>>> Function() onLoadMore;
  final Widget Function(BuildContext, Map<String, dynamic>, int) commentBuilder;

  const LazyCommentsList({
    super.key,
    required this.onLoadInitial,
    required this.onLoadMore,
    required this.commentBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LazyLoadList<Map<String, dynamic>>(
      onLoadInitial: onLoadInitial,
      onLoadMore: onLoadMore,
      itemBuilder: commentBuilder,
      separator: const Divider(height: 1),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      enablePullToRefresh: false,
    );
  }
}

// Grid version for images/media
class LazyGridView<T> extends StatefulWidget {
  final Future<List<T>> Function() onLoadInitial;
  final Future<List<T>> Function() onLoadMore;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsets? padding;

  const LazyGridView({
    super.key,
    required this.onLoadInitial,
    required this.onLoadMore,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.childAspectRatio = 1,
    this.padding,
  });

  @override
  State<LazyGridView<T>> createState() => _LazyGridViewState<T>();
}

class _LazyGridViewState<T> extends State<LazyGridView<T>> {
  final List<T> _items = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newItems = await widget.onLoadInitial();
      setState(() {
        _items.clear();
        _items.addAll(newItems);
        _hasMore = newItems.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newItems = await widget.onLoadMore();
      setState(() {
        _items.addAll(newItems);
        _hasMore = newItems.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: GridView.builder(
        controller: _scrollController,
        padding: widget.padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          mainAxisSpacing: widget.mainAxisSpacing,
          crossAxisSpacing: widget.crossAxisSpacing,
          childAspectRatio: widget.childAspectRatio,
        ),
        itemCount: _items.length + (_isLoadingMore ? widget.crossAxisCount : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(child: CircularProgressIndicator());
          }

          return widget.itemBuilder(context, _items[index], index);
        },
      ),
    );
  }
}