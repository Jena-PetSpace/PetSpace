import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'features/emotion/data/services/gemini_ai_service.dart';
import 'features/emotion/data/models/emotion_analysis_model.dart';
import 'config/api_config.dart';

void main() {
  runApp(const GeminiTestApp());
}

class GeminiTestApp extends StatelessWidget {
  const GeminiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini AI 테스트',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GeminiTestPage(),
    );
  }
}

class GeminiTestPage extends StatefulWidget {
  const GeminiTestPage({super.key});

  @override
  State<GeminiTestPage> createState() => _GeminiTestPageState();
}

class _GeminiTestPageState extends State<GeminiTestPage> {
  final GeminiAIService _geminiService = GeminiAIService();
  File? _selectedImage;
  EmotionScoresModel? _analysisResult;
  bool _isAnalyzing = false;
  String? _errorMessage;

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _analysisResult = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '이미지 선택 오류: $e';
      });
    }
  }

  Future<void> _analyzeEmotion() async {
    if (_selectedImage == null) {
      setState(() {
        _errorMessage = '먼저 이미지를 선택해주세요.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result =
          await _geminiService.analyzeEmotionFromImage(_selectedImage!);
      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '감정 분석 오류: $e';
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini AI 감정분석 테스트'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API 설정 상태
            Card(
              color: ApiConfig.isGeminiConfigured
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔧 API 설정 상태',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gemini API: ${ApiConfig.isGeminiConfigured ? "✅ 설정됨" : "❌ 미설정"}',
                      style: TextStyle(
                        color: ApiConfig.isGeminiConfigured
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (ApiConfig.isGeminiConfigured)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'API 키: ${ApiConfig.geminiApiKey.substring(0, 10)}...',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 이미지 선택 버튼
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo),
              label: const Text('이미지 선택'),
            ),

            const SizedBox(height: 16),

            // 선택된 이미지 표시
            if (_selectedImage != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 분석 버튼
            ElevatedButton.icon(
              onPressed: _selectedImage != null && !_isAnalyzing
                  ? _analyzeEmotion
                  : null,
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.analytics),
              label: Text(_isAnalyzing ? '분석 중...' : 'Gemini AI 감정 분석'),
            ),

            const SizedBox(height: 20),

            // 에러 메시지
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),

            // 분석 결과
            if (_analysisResult != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎯 감정 분석 결과',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildEmotionRow('😊 행복함', _analysisResult!.happiness),
                      _buildEmotionRow('😢 슬픔', _analysisResult!.sadness),
                      _buildEmotionRow('😰 불안함', _analysisResult!.anxiety),
                      _buildEmotionRow('😴 졸림', _analysisResult!.sleepiness),
                      _buildEmotionRow('🤔 호기심', _analysisResult!.curiosity),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionRow(String emotion, double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(emotion),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getEmotionColor(score),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(score * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Color _getEmotionColor(double score) {
    if (score > 0.6) return Colors.red;
    if (score > 0.4) return Colors.orange;
    if (score > 0.2) return Colors.yellow;
    return Colors.green;
  }
}
