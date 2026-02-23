import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';

abstract class ImageService {
  Future<File?> pickImageFromCamera();
  Future<File?> pickImageFromGallery();
  Future<File> processImage(File imageFile);
  Future<String> saveImageToLocal(File imageFile, String fileName);
}

class ImageServiceImpl implements ImageService {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: AppConstants.imageQuality,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) return null;

      final imageFile = File(image.path);

      // 이미지 크기 검증
      final fileSize = await imageFile.length();
      if (fileSize > AppConstants.maxImageSize) {
        throw const ImageException('이미지 파일이 너무 큽니다. (최대 5MB)');
      }

      return await processImage(imageFile);
    } catch (e) {
      if (e is ImageException) {
        rethrow;
      }
      throw ImageException('카메라에서 이미지를 가져오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: AppConstants.imageQuality,
      );

      if (image == null) return null;

      final imageFile = File(image.path);

      // 이미지 크기 검증
      final fileSize = await imageFile.length();
      if (fileSize > AppConstants.maxImageSize) {
        throw const ImageException('이미지 파일이 너무 큽니다. (최대 5MB)');
      }

      return await processImage(imageFile);
    } catch (e) {
      if (e is ImageException) {
        rethrow;
      }
      throw ImageException('갤러리에서 이미지를 가져오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<File> processImage(File imageFile) async {
    try {
      // 이미지 읽기
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw const ImageException('이미지를 디코딩할 수 없습니다.');
      }

      // 이미지 최적화
      final processedImage = _optimizeImage(image);

      // 임시 파일로 저장
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final processedBytes =
          img.encodeJpg(processedImage, quality: AppConstants.imageQuality);
      await tempFile.writeAsBytes(processedBytes);

      return tempFile;
    } catch (e) {
      if (e is ImageException) {
        rethrow;
      }
      throw ImageException('이미지 처리 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<String> saveImageToLocal(File imageFile, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${appDir.path}/images');

      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      final savedFile = File('${imageDir.path}/$fileName');
      await imageFile.copy(savedFile.path);

      return savedFile.path;
    } catch (e) {
      throw FileSystemException('이미지를 로컬에 저장하는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  img.Image _optimizeImage(img.Image image) {
    // 1. 이미지 회전 보정 (EXIF 정보 기반)
    img.Image orientedImage = img.bakeOrientation(image);

    // 2. 크기 조정 (긴 변을 1024px로 제한)
    const maxDimension = 1024;
    img.Image resizedImage;

    if (orientedImage.width > maxDimension ||
        orientedImage.height > maxDimension) {
      if (orientedImage.width > orientedImage.height) {
        resizedImage = img.copyResize(
          orientedImage,
          width: maxDimension,
          height: (orientedImage.height * maxDimension / orientedImage.width)
              .round(),
        );
      } else {
        resizedImage = img.copyResize(
          orientedImage,
          height: maxDimension,
          width: (orientedImage.width * maxDimension / orientedImage.height)
              .round(),
        );
      }
    } else {
      resizedImage = orientedImage;
    }

    // 3. 정사각형 크롭 (감정 분석을 위한 일관된 형태)
    final size = resizedImage.width < resizedImage.height
        ? resizedImage.width
        : resizedImage.height;

    final cropX = (resizedImage.width - size) ~/ 2;
    final cropY = (resizedImage.height - size) ~/ 2;

    final croppedImage = img.copyCrop(
      resizedImage,
      x: cropX,
      y: cropY,
      width: size,
      height: size,
    );

    // 4. 색상 보정 (밝기, 대비 조정)
    final adjustedImage = img.adjustColor(
      croppedImage,
      brightness: 1.1,
      contrast: 1.1,
    );

    return adjustedImage;
  }

  // 이미지 품질 검증 (현재 미사용)
  /*
  bool _isValidImage(img.Image image) {
    // 최소 해상도 확인
    const minResolution = 224;
    if (image.width < minResolution || image.height < minResolution) {
      return false;
    }

    // 이미지 비율 확인 (너무 극단적인 비율 제외)
    final aspectRatio = image.width / image.height;
    if (aspectRatio < 0.3 || aspectRatio > 3.0) {
      return false;
    }

    return true;
  }
  */
}
