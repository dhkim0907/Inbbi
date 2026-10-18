import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/category_tree_selector.dart';
import '../../core/widgets/tree_selection_card.dart';
import 'data_collection_preferences.dart';

class DataCollectionSettingsCard extends StatefulWidget {
  const DataCollectionSettingsCard({super.key, this.preferences});

  final DataCollectionPreferences? preferences;

  @override
  State<DataCollectionSettingsCard> createState() =>
      _DataCollectionSettingsCardState();
}

class _DataCollectionSettingsCardState
    extends State<DataCollectionSettingsCard> {
  static const _categories = [
    CategoryNode(
      id: 'sources',
      label: '연동 서비스',
      selectable: false,
      children: [
        CategoryNode(id: 'portal', label: '인하대 포털'),
        CategoryNode(id: 'iClass', label: 'I-Class'),
        CategoryNode(id: 'googleCalendar', label: 'Google Calendar'),
      ],
    ),
  ];

  late final DataCollectionPreferences _preferences;
  late final bool _ownsPreferences;

  @override
  void initState() {
    super.initState();
    _ownsPreferences = widget.preferences == null;
    _preferences =
        widget.preferences ??
        DataCollectionPreferences(LocalDataCollectionPreferenceStorage());
    _preferences.initialize();
  }

  @override
  void dispose() {
    if (_ownsPreferences) _preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _preferences,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TreeSelectionCard(
            title: '데이터 수집 대상',
            description: '수집 대상 선택을 저장해요. 실제 수집 기능과의 연결은 준비 중이에요.',
            categories: _categories,
            selectedIds: _preferences.selectedSources
                .map((source) => source.name)
                .toSet(),
            enabled: _preferences.initialized && !_preferences.busy,
            onSelectionChanged: (ids) => _preferences.setSelectedSources({
              for (final source in DataSource.values)
                if (ids.contains(source.name)) source,
            }),
          ),
          if (_preferences.error != null)
            Text(
              _preferences.error!,
              style: const TextStyle(color: AppColors.error),
            ),
        ],
      ),
    );
  }
}
