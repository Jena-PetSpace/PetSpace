import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../pets/domain/entities/pet.dart';

class QuickActionsWidget extends StatelessWidget {
  final List<Pet> pets;

  const QuickActionsWidget({
    super.key,
    required this.pets,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '빠른 액션',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _QuickActionButton(
                  icon: Icons.camera_alt,
                  label: '감정 분석',
                  color: Theme.of(context).primaryColor,
                  onTap: () => context.push('/emotion-analysis'),
                ),
                _QuickActionButton(
                  icon: Icons.pets,
                  label: '반려동물',
                  color: Colors.orange,
                  onTap: () => context.push('/pet-management'),
                ),
                _QuickActionButton(
                  icon: Icons.article,
                  label: '포스트 작성',
                  color: Colors.green,
                  onTap: () => context.push('/create-post'),
                ),
                _QuickActionButton(
                  icon: Icons.history,
                  label: '히스토리',
                  color: Colors.purple,
                  onTap: () => context.push('/emotion-history'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
