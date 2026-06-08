import 'package:equatable/equatable.dart';

/// 펫 뉴스 기사. 저작권 원칙상 제목·출처·발행일·원문 링크만 보유.
/// 본문/요약/썸네일은 저장·표시하지 않음(읽기는 원문 링크아웃).
class NewsArticle extends Equatable {
  final String id;
  final String title;
  final String link; // 원문 URL (또는 구글뉴스 리다이렉트 URL)
  final String sourceName; // 출처(매체명)
  final DateTime? publishedAt;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.link,
    required this.sourceName,
    this.publishedAt,
  });

  @override
  List<Object?> get props => [id, title, link, sourceName, publishedAt];
}
