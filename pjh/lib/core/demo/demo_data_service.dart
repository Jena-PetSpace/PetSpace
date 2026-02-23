import 'package:uuid/uuid.dart';

import '../../features/pets/domain/entities/pet.dart';
import '../../features/social/domain/entities/post.dart';
import '../../features/emotion/domain/entities/emotion_analysis.dart';

/// Demo 데이터 서비스
/// Supabase 연결 없이 앱 테스트를 위한 가짜 데이터 제공
class DemoDataService {
  static final DemoDataService _instance = DemoDataService._internal();
  factory DemoDataService() => _instance;
  DemoDataService._internal();

  final _uuid = const Uuid();

  // Demo 사용자 ID
  final String demoUserId = 'demo-user-123';

  // Demo 반려동물 데이터
  List<Pet> getDemoPets() {
    final now = DateTime.now();
    return [
      Pet(
        id: _uuid.v4(),
        userId: demoUserId,
        name: '몽이',
        type: PetType.dog,
        breed: '말티즈',
        birthDate: DateTime(2021, 3, 15),
        gender: PetGender.male,
        avatarUrl:
            'https://images.unsplash.com/photo-1587300003388-59208cc962cb',
        description: '귀여운 우리 몽이',
        createdAt: now.subtract(const Duration(days: 365)),
        updatedAt: now,
      ),
      Pet(
        id: _uuid.v4(),
        userId: demoUserId,
        name: '냥순이',
        type: PetType.cat,
        breed: '페르시안',
        birthDate: DateTime(2020, 7, 20),
        gender: PetGender.female,
        avatarUrl:
            'https://images.unsplash.com/photo-1574158622682-e40e69881006',
        description: '우아한 고양이',
        createdAt: now.subtract(const Duration(days: 300)),
        updatedAt: now,
      ),
    ];
  }

  // Demo 감정 분석 히스토리
  List<EmotionAnalysis> getDemoEmotionHistory() {
    final now = DateTime.now();
    final pets = getDemoPets();

    return List.generate(15, (index) {
      final date = now.subtract(Duration(days: index));
      final emotions = EmotionScores(
        happiness: 0.6 + (index % 3) * 0.1,
        sadness: 0.1 + (index % 2) * 0.05,
        anxiety: 0.1 - (index % 2) * 0.05,
        sleepiness: 0.15 + (index % 4) * 0.05,
        curiosity: 0.05 + (index % 3) * 0.05,
      );

      return EmotionAnalysis(
        id: _uuid.v4(),
        userId: demoUserId,
        petId: pets.first.id,
        imageUrl:
            'https://images.unsplash.com/photo-1587300003388-59208cc962cb',
        localImagePath: '/demo/image_$index.jpg',
        emotions: emotions,
        confidence: 0.85 + (index % 10) * 0.01,
        analyzedAt: date,
        tags: index % 3 == 0 ? ['행복', '산책'] : ['일상'],
        memo: index % 5 == 0 ? '오늘은 기분이 좋아보여요!' : null,
      );
    });
  }

  // Demo 소셜 포스트
  List<Post> getDemoPosts() {
    final now = DateTime.now();
    final pets = getDemoPets();

    return [
      Post(
        id: _uuid.v4(),
        authorId: demoUserId,
        authorName: '데모 사용자',
        authorProfileImage: 'https://ui-avatars.com/api/?name=Demo+User',
        type: PostType.emotionAnalysis,
        content: '오늘 몽이가 너무 행복해보여요! 🐶',
        imageUrls: const [
          'https://images.unsplash.com/photo-1587300003388-59208cc962cb'
        ],
        emotionAnalysis: EmotionAnalysis(
          id: _uuid.v4(),
          userId: demoUserId,
          petId: pets.first.id,
          imageUrl:
              'https://images.unsplash.com/photo-1587300003388-59208cc962cb',
          localImagePath: '/demo/post1.jpg',
          emotions: const EmotionScores(
            happiness: 0.85,
            sadness: 0.02,
            anxiety: 0.03,
            sleepiness: 0.05,
            curiosity: 0.05,
          ),
          confidence: 0.92,
          analyzedAt: now.subtract(const Duration(hours: 2)),
          tags: const ['행복', '산책'],
        ),
        tags: const ['행복한하루', '몽이일상'],
        createdAt: now.subtract(const Duration(hours: 2)),
        likesCount: 24,
        commentsCount: 5,
        isLikedByCurrentUser: false,
      ),
      Post(
        id: _uuid.v4(),
        authorId: 'other-user-1',
        authorName: '반려인A',
        authorProfileImage: 'https://ui-avatars.com/api/?name=User+A',
        type: PostType.image,
        content: '우리 냥이도 오늘 기분 좋아요! 😺',
        imageUrls: const [
          'https://images.unsplash.com/photo-1574158622682-e40e69881006'
        ],
        tags: const ['고양이', '일상'],
        createdAt: now.subtract(const Duration(hours: 5)),
        likesCount: 18,
        commentsCount: 3,
        isLikedByCurrentUser: true,
      ),
      Post(
        id: _uuid.v4(),
        authorId: 'other-user-2',
        authorName: '반려인B',
        authorProfileImage: 'https://ui-avatars.com/api/?name=User+B',
        type: PostType.emotionAnalysis,
        content: '산책 후 졸린 표정 ㅎㅎ',
        imageUrls: const [
          'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e'
        ],
        emotionAnalysis: EmotionAnalysis(
          id: _uuid.v4(),
          userId: 'other-user-2',
          petId: _uuid.v4(),
          imageUrl:
              'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e',
          localImagePath: '/demo/post3.jpg',
          emotions: const EmotionScores(
            happiness: 0.20,
            sadness: 0.05,
            anxiety: 0.05,
            sleepiness: 0.70,
            curiosity: 0.00,
          ),
          confidence: 0.88,
          analyzedAt: now.subtract(const Duration(hours: 8)),
          tags: const ['졸음', '산책'],
        ),
        tags: const ['산책', '졸음'],
        createdAt: now.subtract(const Duration(hours: 8)),
        likesCount: 32,
        commentsCount: 7,
        isLikedByCurrentUser: false,
      ),
    ];
  }

  // Demo 알림
  List<Map<String, dynamic>> getDemoNotifications() {
    final now = DateTime.now();
    return [
      {
        'id': _uuid.v4(),
        'type': 'like',
        'title': '반려인A님이 좋아요를 눌렀습니다',
        'body': '게시물: "오늘 몽이가 너무 행복해보여요! 🐶"',
        'timestamp': now.subtract(const Duration(minutes: 30)),
        'isRead': false,
      },
      {
        'id': _uuid.v4(),
        'type': 'comment',
        'title': '반려인B님이 댓글을 남겼습니다',
        'body': '정말 귀엽네요! ㅎㅎ',
        'timestamp': now.subtract(const Duration(hours: 2)),
        'isRead': false,
      },
      {
        'id': _uuid.v4(),
        'type': 'follow',
        'title': '반려인C님이 팔로우하기 시작했습니다',
        'body': '',
        'timestamp': now.subtract(const Duration(hours: 5)),
        'isRead': true,
      },
    ];
  }

  // Demo 댓글
  List<Map<String, dynamic>> getDemoComments(String postId) {
    final now = DateTime.now();
    return [
      {
        'id': _uuid.v4(),
        'postId': postId,
        'authorId': 'user-1',
        'authorName': '반려인A',
        'authorPhoto': 'https://ui-avatars.com/api/?name=User+A',
        'content': '정말 귀엽네요! 🥰',
        'createdAt': now.subtract(const Duration(hours: 1)),
      },
      {
        'id': _uuid.v4(),
        'postId': postId,
        'authorId': 'user-2',
        'authorName': '반려인B',
        'authorPhoto': 'https://ui-avatars.com/api/?name=User+B',
        'content': '우리 강아지랑 비슷해요 ㅎㅎ',
        'createdAt': now.subtract(const Duration(minutes: 30)),
      },
    ];
  }

  // Demo 사용자 프로필
  Map<String, dynamic> getDemoUserProfile() {
    return {
      'id': demoUserId,
      'email': 'demo@meongnyangdiary.com',
      'displayName': '데모 사용자',
      'photoUrl': 'https://ui-avatars.com/api/?name=Demo+User',
      'bio': '반려동물을 사랑하는 사람입니다 🐶🐱',
      'postsCount': 15,
      'followersCount': 48,
      'followingCount': 32,
      'petsCount': 2,
    };
  }

  // 랜덤 감정 분석 결과 생성
  EmotionAnalysis generateRandomEmotionAnalysis({
    required String userId,
    required String petId,
    required String imageUrl,
    required String localImagePath,
  }) {
    final emotions = _generateRandomEmotions();

    return EmotionAnalysis(
      id: _uuid.v4(),
      userId: userId,
      petId: petId,
      imageUrl: imageUrl,
      localImagePath: localImagePath,
      emotions: emotions,
      confidence: 0.75 + (DateTime.now().millisecond % 20) / 100,
      analyzedAt: DateTime.now(),
      tags: _getTags(emotions.dominantEmotion),
      memo: null,
    );
  }

  EmotionScores _generateRandomEmotions() {
    final base = [0.3, 0.25, 0.2, 0.15, 0.1];
    base.shuffle();

    return EmotionScores(
      happiness: base[0],
      sadness: base[1],
      anxiety: base[2],
      sleepiness: base[3],
      curiosity: base[4],
    );
  }

  List<String> _getTags(String emotion) {
    final tags = {
      'happiness': ['행복', '기쁨'],
      'sadness': ['슬픔', '우울'],
      'anxiety': ['불안', '긴장'],
      'sleepiness': ['졸음', '피곤'],
      'curiosity': ['호기심', '탐색'],
    };
    return tags[emotion] ?? ['일상'];
  }
}
