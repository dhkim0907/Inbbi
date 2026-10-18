import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/base_view.dart';
import '../../core/widgets/notification_bell_button.dart';
import 'notice_source_dialogs.dart';
import 'notice_sources.dart';

class NoticeFeedPage extends StatefulWidget {
  const NoticeFeedPage({super.key, this.sources});
  final NoticeSources? sources;
  @override
  State<NoticeFeedPage> createState() => _NoticeFeedPageState();
}

class _NoticeFeedPageState extends State<NoticeFeedPage> {
  late final _sources =
      widget.sources ?? NoticeSources(PreferencesNoticeSourceStorage());
  final _search = TextEditingController();
  String _selected = 'all';

  @override
  void initState() {
    super.initState();
    unawaited(_sources.initialize());
  }

  @override
  void dispose() {
    _search.dispose();
    if (widget.sources == null) _sources.dispose();
    super.dispose();
  }

  Future<void> _addSource() async {
    final id = await showDialog<String>(
      context: context,
      builder: (_) => NoticeSourceWizard(sources: _sources),
    );
    if (id != null && mounted) setState(() => _selected = id);
  }

  List<_NoticeItem> get _notices => [
    const _NoticeItem(
      'scholarship',
      '장학',
      '2026-1 소프트웨어융합공학과 장학금 신청 안내',
      '학과공지 · 2026.06.02 · 마감 D-3',
    ),
    const _NoticeItem('school', '비교과', '학습지원센터 비교과 프로그램 모집', '학습지원센터 · 새 공지'),
    const _NoticeItem('school', '학사', '인하대학교 학사일정 변경 안내', '학교공지 · 일정 추가 가능'),
    for (final source in _sources.sources.where((s) => !s.builtIn)) ...[
      _NoticeItem(
        source.id,
        source.name,
        '${source.name} · ${switch (source.id) {
          'career' => '하반기 채용설명회 신청 안내',
          'global' => '교환학생 설명회 신청 안내',
          _ => '신입 회원 모집 안내',
        }}',
        '예시 공지 · 2026.09.30',
      ),
      _NoticeItem(
        source.id,
        source.name,
        '${source.name} · ${switch (source.id) {
          'career' => '이력서 작성 특강 모집',
          'global' => '국제교류 프로그램 모집',
          _ => '10월 활동 일정 안내',
        }}',
        '예시 공지 · 2026.09.29',
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _sources,
    builder: (context, _) {
      final selected = _sources.sources.any((s) => s.id == _selected)
          ? _selected
          : 'all';
      final query = _search.text.trim().toLowerCase();
      final notices = _notices
          .where(
            (item) =>
                (selected == 'all' || item.sourceId == selected) &&
                item.title.toLowerCase().contains(query),
          )
          .toList();
      return BaseView(
        backgroundColor: const Color(0xFFF6F7F9),
        mobileBuilder: (_) => _body(notices, selected, false),
        desktopBuilder: (_) => _body(notices, selected, true),
      );
    },
  );

  Widget _body(List<_NoticeItem> notices, String selected, bool desktop) =>
      SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          desktop ? 60 : 20,
          desktop ? 46 : 36,
          desktop ? 60 : 20,
          36,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '공지 모아보기',
                        style: AppTextStyles.heading1.copyWith(
                          fontSize: 27,
                          letterSpacing: -1,
                          color: const Color(0xFF282F38),
                        ),
                      ),
                      if (desktop) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '학교·학과·장학 공지를 한곳에서 확인해요.',
                          style: TextStyle(fontSize: 12, color: noticeMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                NotificationBellButton(
                  backgroundColor: noticeBrand,
                  icon: SizedBox.square(
                    dimension: 19,
                    child: SvgPicture.asset(
                      'assets/icons/notice/bell.svg',
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            if (_sources.busy) const LinearProgressIndicator(),
            if (_sources.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sources.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    if (!_sources.ready)
                      TextButton(
                        onPressed: _sources.initialize,
                        child: const Text('다시 시도'),
                      ),
                  ],
                ),
              ),
            TextField(
              key: const ValueKey('notice-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13),
              decoration: noticeInput('공지 검색').copyWith(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
              ),
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final source in _sources.sources)
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: ActionChip(
                              key: ValueKey('notice-filter:${source.id}'),
                              onPressed: () =>
                                  setState(() => _selected = source.id),
                              label: Text(
                                source.name,
                                style: TextStyle(
                                  fontSize: desktop ? 13 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected == source.id
                                      ? Colors.white
                                      : const Color(0xFF282F38),
                                ),
                              ),
                              backgroundColor: selected == source.id
                                  ? Color(source.color)
                                  : Colors.white,
                              surfaceTintColor: Colors.transparent,
                              shape: const StadiumBorder(),
                              side: BorderSide(
                                color: selected == source.id
                                    ? Color(source.color)
                                    : noticeBorder,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 8,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                _action(
                  '공지 페이지 추가',
                  const Text(
                    '＋',
                    style: TextStyle(fontSize: 24, color: noticeBrand),
                  ),
                  _addSource,
                ),
                const SizedBox(width: 5),
                _action(
                  '수집처 설정',
                  SizedBox.square(
                    dimension: 19,
                    child: SvgPicture.asset(
                      'assets/icons/notice/settings.svg',
                      excludeFromSemantics: true,
                    ),
                  ),
                  () => showDialog<void>(
                    context: context,
                    builder: (_) => NoticeSourceManager(sources: _sources),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            if (notices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  '표시할 공지가 없어요.',
                  style: TextStyle(fontSize: 13, color: noticeMuted),
                ),
              ),
            for (final notice in notices)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NoticeCard(
                  notice: notice,
                  color: Color(
                    _sources.sources
                        .firstWhere((s) => s.id == notice.sourceId)
                        .color,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _action(String tooltip, Widget icon, VoidCallback onPressed) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: noticeBorder),
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: !_sources.ready || _sources.busy ? null : onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 38, height: 39),
          icon: icon,
        ),
      );
}

class _NoticeItem {
  const _NoticeItem(this.sourceId, this.badge, this.title, this.meta);
  final String sourceId;
  final String badge;
  final String title;
  final String meta;
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.color});
  final _NoticeItem notice;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: noticeBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .094),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            notice.badge,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 11),
        Text(
          notice.title,
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            fontWeight: FontWeight.w700,
            color: Color(0xFF282F38),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          notice.meta,
          style: const TextStyle(fontSize: 12, height: 1.6, color: noticeMuted),
        ),
      ],
    ),
  );
}
