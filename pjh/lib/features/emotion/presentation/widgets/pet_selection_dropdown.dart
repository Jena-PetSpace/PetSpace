import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../pets/domain/entities/pet.dart';

class PetSelectionDropdown extends StatelessWidget {
  final List<Pet> pets;
  final Pet? selectedPet;
  final Function(Pet?) onChanged;
  final String? hint;
  final bool analyzeWithoutPet;
  final Function(bool) onAnalyzeWithoutPetChanged;

  const PetSelectionDropdown({
    super.key,
    required this.pets,
    required this.selectedPet,
    required this.onChanged,
    this.hint,
    required this.analyzeWithoutPet,
    required this.onAnalyzeWithoutPetChanged,
  });

  Widget _buildPetAvatar(Pet pet) {
    if (pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty) {
      return SizedBox(
        width: 40,
        height: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CachedNetworkImage(
            imageUrl: pet.avatarUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => _buildEmojiAvatar(pet),
            errorWidget: (_, __, ___) => _buildEmojiAvatar(pet),
          ),
        ),
      );
    }
    return _buildEmojiAvatar(pet);
  }

  Widget _buildEmojiAvatar(Pet pet) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        pet.type == PetType.dog ? '🐕' : '🐱',
        style: const TextStyle(fontSize: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 드롭다운
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Pet>(
              value: selectedPet,
              hint: Text(hint ?? '반려동물을 선택하세요'),
              isExpanded: true,
              itemHeight: 60,
              onChanged: analyzeWithoutPet ? null : onChanged,
              items: pets.map((Pet pet) {
                return DropdownMenuItem<Pet>(
                  value: pet,
                  child: Row(
                    children: [
                      _buildPetAvatar(pet),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pet.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${pet.typeDisplayName} • ${pet.breed ?? '품종 미상'} • ${pet.displayAge}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // "반려동물 없이 분석" 체크박스
        GestureDetector(
          onTap: () => onAnalyzeWithoutPetChanged(!analyzeWithoutPet),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: analyzeWithoutPet
                  ? Colors.orange.shade50
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: analyzeWithoutPet
                    ? Colors.orange.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  analyzeWithoutPet
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: analyzeWithoutPet ? Colors.orange : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '등록된 반려동물 없이 분석',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '반려동물을 등록하지 않았거나, 특정 반려동물을 선택하지 않고 분석합니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
