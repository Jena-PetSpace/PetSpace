import "package:flutter/material.dart";

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("반려동물 사진 촬영"),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 100,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text("카메라 기능이 여기에 구현됩니다."),
          ],
        ),
      ),
    );
  }
}
