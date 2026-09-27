import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 셀렉터에 표시할 카테고리. [id]는 트리 전체에서 고유해야 한다.
class CategoryNode {
  const CategoryNode({
    required this.id,
    required this.label,
    this.children = const [],
    this.selectable = true,
  });

  final String id;
  final String label;
  final List<CategoryNode> children;
  final bool selectable;
}

/// 선택 상태는 부모가 관리하고, 펼침 상태만 위젯 내부에서 관리한다.
class CategoryTreeSelector extends StatefulWidget {
  const CategoryTreeSelector({
    super.key,
    required this.categories,
    this.selectedId,
    this.onSelected,
    this.selectedIds,
    this.onSelectionChanged,
  }) : assert(
         (onSelected != null &&
                 selectedIds == null &&
                 onSelectionChanged == null) ||
             (onSelected == null &&
                 selectedIds != null &&
                 onSelectionChanged != null),
         '단일 선택 또는 다중 선택 콜백을 지정해야 합니다.',
       );

  final List<CategoryNode> categories;
  final String? selectedId;
  final ValueChanged<CategoryNode>? onSelected;

  /// 다중 선택에서는 ID 집합을 부모 위젯이 관리한다.
  final Set<String>? selectedIds;
  final ValueChanged<Set<String>>? onSelectionChanged;

  @override
  State<CategoryTreeSelector> createState() => _CategoryTreeSelectorState();
}

class _CategoryTreeSelectorState extends State<CategoryTreeSelector> {
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _expandSelectedPath();
  }

  @override
  void didUpdateWidget(covariant CategoryTreeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId ||
        oldWidget.selectedIds != widget.selectedIds ||
        oldWidget.categories != widget.categories) {
      _expandSelectedPath();
    }
  }

  void _expandSelectedPath() {
    bool visit(CategoryNode node) {
      if (node.id == widget.selectedId ||
          (widget.selectedIds?.contains(node.id) ?? false)) {
        return true;
      }
      var containsSelected = false;
      for (final child in node.children) {
        if (visit(child)) containsSelected = true;
      }
      if (containsSelected) _expandedIds.add(node.id);
      return containsSelected;
    }

    for (final node in widget.categories) {
      visit(node);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('표시할 카테고리가 없어요.'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final node in widget.categories) _buildNode(node, 0)],
    );
  }

  Widget _buildNode(CategoryNode node, int depth) {
    final hasChildren = node.children.isNotEmpty;
    final expanded = _expandedIds.contains(node.id);
    final selected =
        widget.selectedIds?.contains(node.id) ?? widget.selectedId == node.id;

    void select() {
      final ids = widget.selectedIds;
      if (ids == null) {
        widget.onSelected?.call(node);
        return;
      }
      final next = Set<String>.of(ids);
      if (!next.add(node.id)) next.remove(node.id);
      widget.onSelectionChanged?.call(next);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 12 + depth * 20.0, right: 8),
          child: Row(
            children: [
              Expanded(
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(node.label),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  trailing: !node.selectable
                      ? null
                      : widget.selectedIds != null
                      ? Checkbox(value: selected, onChanged: (_) => select())
                      : selected
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: node.selectable
                      ? select
                      : hasChildren
                      ? () => setState(() {
                          if (expanded) {
                            _expandedIds.remove(node.id);
                          } else {
                            _expandedIds.add(node.id);
                          }
                        })
                      : null,
                ),
              ),
              if (hasChildren)
                IconButton(
                  tooltip: expanded ? '${node.label} 접기' : '${node.label} 펼치기',
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() {
                    if (expanded) {
                      _expandedIds.remove(node.id);
                    } else {
                      _expandedIds.add(node.id);
                    }
                  }),
                ),
            ],
          ),
        ),
        if (hasChildren && expanded)
          for (final child in node.children) _buildNode(child, depth + 1),
      ],
    );
  }
}
