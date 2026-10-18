import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'category_tree_selector.dart';

/// 기능별 트리 데이터와 선택 상태를 받아 표시하는 공통 설정 카드.
class TreeSelectionCard extends StatelessWidget {
  const TreeSelectionCard({
    super.key,
    required this.title,
    required this.description,
    required this.categories,
    required this.selectedIds,
    required this.onSelectionChanged,
    this.enabled = true,
    this.message,
  });

  final String title;
  final String description;
  final List<CategoryNode> categories;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final bool enabled;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description),
            CategoryTreeSelector(
              categories: categories,
              selectedIds: selectedIds,
              onSelectionChanged: enabled ? onSelectionChanged : (_) {},
            ),
            if (message != null) Text(message!),
          ],
        ),
      ),
    );
  }
}
