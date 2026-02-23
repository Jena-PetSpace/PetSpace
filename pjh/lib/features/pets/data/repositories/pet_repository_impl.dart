import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../domain/entities/pet.dart';
import '../../domain/repositories/pet_repository.dart';
import '../models/pet_model.dart';

/// PetRepository 구현
/// TRD 문서 183-194줄 참조: pets 테이블 구조
/// - owner_id (FK to users), name, species, breed, age, gender, photo_url
class PetRepositoryImpl implements PetRepository {
  final SupabaseClient supabaseClient;
  final NetworkInfo networkInfo;
  final ImageUploadService imageUploadService;

  PetRepositoryImpl({
    required this.supabaseClient,
    required this.networkInfo,
    required this.imageUploadService,
  });

  /// 테이블 이름 상수
  static const String _tableName = 'pets';

  @override
  Future<Either<Failure, List<Pet>>> getUserPets(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      // PostgreSQL 쿼리: SELECT * FROM pets WHERE user_id = userId ORDER BY created_at DESC
      final response = await supabaseClient
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // List<dynamic>을 List<PetModel>로 변환
      final pets = (response as List<dynamic>)
          .map((json) => PetModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(pets);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return Left(
          GeneralFailure(message: '반려동물 목록 조회 중 오류 발생: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Pet>> getPetById(String petId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      // PostgreSQL 쿼리: SELECT * FROM pets WHERE id = petId LIMIT 1
      final response = await supabaseClient
          .from(_tableName)
          .select()
          .eq('id', petId)
          .maybeSingle();

      if (response == null) {
        return const Left(
            DatabaseFailure(message: '해당 반려동물을 찾을 수 없습니다.'));
      }

      final pet = PetModel.fromJson(response);
      return Right(pet);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return Left(
          GeneralFailure(message: '반려동물 조회 중 오류 발생: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Pet>> addPet(Pet pet) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final petModel = PetModel.fromEntity(pet);

      // PostgreSQL INSERT: INSERT INTO pets (...) VALUES (...) RETURNING *
      // TRD 문서: RLS 정책 적용됨 - 사용자는 자신의 반려동물만 추가 가능
      final response = await supabaseClient
          .from(_tableName)
          .insert(petModel.toInsertJson())
          .select()
          .single();

      final createdPet = PetModel.fromJson(response);
      return Right(createdPet);
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        // Foreign Key Violation
        return const Left(
            DatabaseFailure(message: '유효하지 않은 사용자입니다.'));
      } else if (e.code == '23505') {
        // Unique Violation (unlikely for pets)
        return const Left(
            DatabaseFailure(message: '이미 존재하는 반려동물입니다.'));
      }
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return Left(
          GeneralFailure(message: '반려동물 등록 중 오류 발생: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Pet>> updatePet(Pet pet) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final petModel = PetModel.fromEntity(pet);

      // PostgreSQL UPDATE: UPDATE pets SET ... WHERE id = petId RETURNING *
      // TRD 문서: RLS 정책 - 사용자는 자신의 반려동물만 수정 가능
      final response = await supabaseClient
          .from(_tableName)
          .update(petModel.toUpdateJson())
          .eq('id', pet.id)
          .select()
          .single();

      final updatedPet = PetModel.fromJson(response);
      return Right(updatedPet);
    } on PostgrestException catch (e) {
      if (e.code == '404' || e.message.contains('No rows found')) {
        return const Left(
            DatabaseFailure(message: '해당 반려동물을 찾을 수 없습니다.'));
      }
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return Left(
          GeneralFailure(message: '반려동물 정보 수정 중 오류 발생: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deletePet(String petId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      // 먼저 반려동물 정보 조회 (이미지 URL 확인용)
      final petResult = await getPetById(petId);

      // PostgreSQL DELETE: DELETE FROM pets WHERE id = petId
      // TRD 문서: CASCADE 설정으로 관련 데이터도 자동 삭제
      await supabaseClient.from(_tableName).delete().eq('id', petId);

      // 반려동물 프로필 이미지 삭제 시도 (선택적)
      petResult.fold(
        (failure) => null, // 이미지가 없거나 조회 실패해도 삭제는 성공으로 처리
        (pet) async {
          if (pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty) {
            try {
              await imageUploadService.deleteImage(pet.avatarUrl!);
            } catch (e) {
              // 이미지 삭제 실패해도 무시 (반려동물 데이터는 이미 삭제됨)
            }
          }
        },
      );

      return const Right(null);
    } on PostgrestException catch (e) {
      if (e.code == '404' || e.message.contains('No rows found')) {
        return const Left(
            DatabaseFailure(message: '해당 반려동물을 찾을 수 없습니다.'));
      }
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return Left(
          GeneralFailure(message: '반려동물 삭제 중 오류 발생: ${e.toString()}'));
    }
  }

  /// 반려동물 프로필 이미지 업로드
  /// TRD 문서 250-264줄: Supabase Storage 구조
  /// /images/pets/{petId}/profile/
  Future<Either<Failure, String>> uploadPetProfileImage(
    String petId,
    File imageFile,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      // 반려동물 소유권 확인
      final petResult = await getPetById(petId);

      return petResult.fold(
        (failure) => Left(failure),
        (pet) async {
          try {
            // 이미지 업로드 (Supabase Storage: images 버킷)
            final userId = supabaseClient.auth.currentUser?.id;
            if (userId == null) {
              return const Left(
                  AuthFailure(message: '로그인이 필요합니다.'));
            }

            // 기존 이미지가 있으면 삭제
            if (pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty) {
              try {
                await imageUploadService.deleteImage(pet.avatarUrl!);
              } catch (e) {
                // 기존 이미지 삭제 실패는 무시
              }
            }

            // 새 이미지 업로드
            final fileName =
                'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final destinationPath = 'pets/$petId/profile/$fileName';

            final imageBytes = await imageFile.readAsBytes();
            await supabaseClient.storage.from('images').uploadBinary(
                  destinationPath,
                  imageBytes,
                  fileOptions: const FileOptions(
                    contentType: 'image/jpeg',
                    cacheControl: '3600',
                    upsert: false,
                  ),
                );

            // Public URL 생성
            final photoUrl = supabaseClient.storage
                .from('images')
                .getPublicUrl(destinationPath);

            // DB 업데이트
            await supabaseClient
                .from(_tableName)
                .update({'photo_url': photoUrl}).eq('id', petId);

            return Right(photoUrl);
          } catch (e) {
            return Left(GeneralFailure(
                message: '이미지 업로드 중 오류 발생: ${e.toString()}'));
          }
        },
      );
    } catch (e) {
      return Left(
          GeneralFailure(message: '이미지 업로드 중 오류 발생: ${e.toString()}'));
    }
  }

  /// 특정 사용자의 반려동물 수 조회
  Future<Either<Failure, int>> getPetCountByUserId(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      // PostgreSQL COUNT: SELECT COUNT(*) FROM pets WHERE user_id = userId
      final response = await supabaseClient
          .from(_tableName)
          .select('id')
          .eq('user_id', userId);

      final count = (response as List).length;
      return Right(count);
    } on PostgrestException {
      return const Left(DatabaseFailure(message: 'DB 오류'));
    } catch (e) {
      return Left(
          GeneralFailure(message: '반려동물 수 조회 중 오류 발생: ${e.toString()}'));
    }
  }

  /// 품종 검색 (자동완성용)
  /// Supabase breeds 테이블에서 품종 데이터 조회
  Future<Either<Failure, List<String>>> searchBreeds(
    PetType petType,
    String query,
  ) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final species = petType == PetType.dog ? 'dog' : 'cat';

      // Supabase RPC 함수 호출
      try {
        final response = await supabaseClient.rpc(
          'search_breeds',
          params: {
            'p_species': species,
            'p_query': query,
            'p_limit': 20,
          },
        );

        if (response != null && response is List) {
          final breeds = response
              .map((item) => item['name_ko'] as String)
              .toList();

          return Right(breeds);
        }
      } catch (rpcError) {
        // RPC 실패 시 직접 쿼리로 폴백
      }

      // RPC 함수가 없으면 직접 쿼리
      final fallbackResponse = await supabaseClient
          .from('breeds')
          .select('name_ko')
          .eq('species', species)
          .eq('is_active', true)
          .or('name_ko.ilike.%$query%,name_en.ilike.%$query%')
          .order('display_order')
          .order('name_ko')
          .limit(20);

      final breeds = (fallbackResponse as List)
          .map((item) => item['name_ko'] as String)
          .toList();

      return Right(breeds);
    } catch (e) {
      // 에러 발생 시 기본 품종 목록 반환 (폴백)
      final fallbackBreeds = petType == PetType.dog
          ? ['말티즈', '푸들', '치와와', '포메라니안', '시바견', '비글', '웰시코기', '골든 리트리버', '래브라도 리트리버', '진돗개']
          : ['코리안 숏헤어', '페르시안', '러시안 블루', '샴', '스코티시 폴드', '먼치킨', '아메리칸 숏헤어', '메인쿤', '브리티시 숏헤어', '뱅갈'];

      final filtered = fallbackBreeds
          .where((breed) => breed.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return Right(filtered);
    }
  }

  /// 전체 품종 목록 조회
  Future<Either<Failure, List<String>>> getAllBreeds(PetType petType) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final species = petType == PetType.dog ? 'dog' : 'cat';

      // Supabase RPC 함수 호출
      try {
        final response = await supabaseClient.rpc(
          'get_all_breeds',
          params: {'p_species': species},
        );

        if (response != null && response is List) {
          final breeds = response
              .map((item) => item['name_ko'] as String)
              .toList();

          return Right(breeds);
        }
      } catch (rpcError) {
        // RPC 실패 시 직접 쿼리로 폴백
      }

      // 직접 쿼리
      final response = await supabaseClient
          .from('breeds')
          .select('name_ko')
          .eq('species', species)
          .eq('is_active', true)
          .order('display_order')
          .order('name_ko');

      final breeds = (response as List)
          .map((item) => item['name_ko'] as String)
          .toList();

      return Right(breeds);
    } catch (e) {
      return Left(ServerFailure(message: '품종 목록 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }
}
