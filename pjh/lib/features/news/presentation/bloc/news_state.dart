part of 'news_bloc.dart';

abstract class NewsState extends Equatable {
  const NewsState();

  @override
  List<Object?> get props => [];
}

class NewsInitial extends NewsState {
  const NewsInitial();
}

class NewsLoading extends NewsState {
  const NewsLoading();
}

class NewsLoaded extends NewsState {
  final List<NewsArticle> articles;
  final bool hasMore;
  final bool isLoadingMore;

  const NewsLoaded({
    required this.articles,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  NewsLoaded copyWith({
    List<NewsArticle>? articles,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return NewsLoaded(
      articles: articles ?? this.articles,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [articles, hasMore, isLoadingMore];
}

class NewsError extends NewsState {
  final String message;

  const NewsError(this.message);

  @override
  List<Object?> get props => [message];
}
