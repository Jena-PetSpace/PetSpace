import "package:flutter/material.dart";

class AnalysisHistoryPage extends StatelessWidget {
  const AnalysisHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("분석 기록"),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 100,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text("분석 기록이 여기에 표시됩니다."),
          ],
        ),
      ),
    );
  }
}
