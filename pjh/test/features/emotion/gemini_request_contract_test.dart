import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/emotion/data/services/gemini_ai_service.dart';

void main() {
  group('Gemini request contract', () {
    test('matches the proxy image count and keeps a size safety margin', () {
      expect(GeminiAIService.maxImagesPerRequest, 5);
      expect(GeminiAIService.maxSourceImageBytes, 5 * 1024 * 1024);
      expect(
        GeminiAIService.maxClientRequestBytes,
        lessThan(12 * 1024 * 1024),
      );
      expect(
        GeminiAIService.estimateBase64Chars(5 * 1024 * 1024),
        lessThan(GeminiAIService.maxImageBase64Chars),
      );
    });

    test('accepts a normal request and enforces the encoded boundary', () {
      final normal = <String, dynamic>{
        'contents': [
          {
            'parts': [
              {'text': 'analyze'},
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': 'abc'},
              },
            ],
          },
        ],
      };
      expect(GeminiAIService.isWithinRequestBudget(normal), isTrue);
      expect(
        GeminiAIService.isEncodedRequestWithinBudget(
          GeminiAIService.maxClientRequestBytes,
        ),
        isTrue,
      );
      expect(
        GeminiAIService.isEncodedRequestWithinBudget(
          GeminiAIService.maxClientRequestBytes + 1,
        ),
        isFalse,
      );
    });
  });
}
