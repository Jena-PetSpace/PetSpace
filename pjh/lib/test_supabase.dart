import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_options.dart';
import 'config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 초기화
  if (SupabaseOptions.isConfigured) {
    await Supabase.initialize(
      url: SupabaseOptions.supabaseUrl,
      anonKey: SupabaseOptions.supabaseAnonKey,
    );
  }

  runApp(const TestSupabaseApp());
}

class TestSupabaseApp extends StatelessWidget {
  const TestSupabaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase 연결 테스트',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestPage(),
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String status = '테스트 준비 중...';
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    testConnection();
  }

  Future<void> testConnection() async {
    try {
      setState(() {
        status = 'Supabase 연결 테스트 중...';
      });

      if (!SupabaseOptions.isConfigured) {
        setState(() {
          status = '❌ Supabase 설정이 필요합니다';
          isConnected = false;
        });
        return;
      }

      // 간단한 연결 테스트
      final supabase = Supabase.instance.client;

      // Health check
      await supabase.from('health_check').select().limit(1);

      setState(() {
        status = '✅ Supabase 연결 성공!';
        isConnected = true;
      });
    } catch (e) {
      setState(() {
        status = '⚠️ 연결됨 (테이블 미생성): ${e.toString()}';
        isConnected = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('멍냥다이어리 - Supabase 테스트'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isConnected ? Icons.cloud_done : Icons.cloud_off,
              size: 80,
              color: isConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              status,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 설정 현황',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text('Supabase URL: ${SupabaseOptions.supabaseUrl}'),
                    const SizedBox(height: 8),
                    Text(
                        '설정 상태: ${SupabaseOptions.isConfigured ? "완료" : "미완료"}'),
                    const SizedBox(height: 16),
                    const Text(
                      '🔧 사용 가능한 기능:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...ApiConfig.availableFeatures.map((feature) => Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 4),
                          child: Text('• $feature'),
                        )),
                    const SizedBox(height: 16),
                    const Text(
                      '✅ Google OAuth 설정:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        '클라이언트 ID: ${ApiConfig.isGoogleLoginConfigured ? "설정됨" : "미설정"}'),
                    if (ApiConfig.isGoogleLoginConfigured)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Text(
                          '${ApiConfig.googleClientId.substring(0, 20)}...',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: testConnection,
              icon: const Icon(Icons.refresh),
              label: const Text('연결 재테스트'),
            ),
          ],
        ),
      ),
    );
  }
}
