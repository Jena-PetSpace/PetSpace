import 'package:flutter/material.dart';

import '../../../../shared/widgets/petspace_app_bar.dart';
import '../../../../shared/widgets/petspace_uiux_v3.dart';

class TermsDetailPage extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback? onAgree;

  const TermsDetailPage({
    super.key,
    required this.title,
    required this.content,
    this.onAgree,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PetSpaceV3Tokens.canvas,
      appBar: PetSpaceAppBar.page(
        title: title,
        backgroundColor: PetSpaceV3Tokens.canvas,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: PetSpaceV3Card(
                  child: SelectionArea(
                    child: Text(
                      content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: PetSpaceV3Tokens.text,
                        height: 1.65,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (onAgree != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: PetSpaceV3PrimaryButton(
                  label: '동의',
                  onPressed: () {
                    onAgree!();
                    Navigator.of(context).pop();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
