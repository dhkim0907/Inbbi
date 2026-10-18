import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import 'notice_sources.dart';

const noticeBrand = Color(0xFF3674BF);
const noticeMuted = Color(0xFF8795A9);
const noticeBorder = Color(0xFFE4E9F0);

InputDecoration noticeInput(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: noticeBorder),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: noticeBorder),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: noticeBrand, width: 2),
  ),
);

class NoticePanel extends StatelessWidget {
  const NoticePanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.actions = const [],
    this.width = 860,
    this.busy = false,
  });
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final double width;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final mobile = AppBreakpoints.of(context) == ScreenSize.mobile;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: noticeBrand),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            minimumSize: const Size(0, 44),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: noticeBrand,
            side: const BorderSide(color: noticeBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 11),
          ),
        ),
      ),
      child: PopScope(
        canPop: !busy,
        child: Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: mobile ? EdgeInsets.zero : const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(mobile ? 0 : 20),
          ),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width,
                maxHeight: mobile ? double.infinity : 760,
              ),
              child: Column(
                mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  subtitle!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: noticeMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: busy ? null : () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close,
                            size: 20,
                            color: noticeMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: noticeBorder),
                  Flexible(
                    fit: mobile ? FlexFit.tight : FlexFit.loose,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: body,
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const Divider(height: 1, color: noticeBorder),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(children: actions),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NoticeColors extends StatelessWidget {
  const NoticeColors({
    super.key,
    required this.color,
    required this.onSelected,
  });
  final int color;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final value in NoticeSources.colors)
        Semantics(
          selected: color == value,
          button: true,
          label: '${value.toRadixString(16)} 색상',
          child: InkWell(
            onTap: () => onSelected(value),
            customBorder: const CircleBorder(),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(value),
                border: color == value
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
                boxShadow: color == value
                    ? [BoxShadow(color: Color(value), spreadRadius: 2)]
                    : null,
              ),
              child: color == value
                  ? const Icon(Icons.check, color: Colors.white, size: 19)
                  : null,
            ),
          ),
        ),
    ],
  );
}

class NoticeSourceWizard extends StatefulWidget {
  const NoticeSourceWizard({super.key, required this.sources, this.source});
  final NoticeSources sources;
  final NoticeSource? source;

  @override
  State<NoticeSourceWizard> createState() => _NoticeSourceWizardState();
}

class _NoticeSourceWizardState extends State<NoticeSourceWizard> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.source?.name);
  late final _url = TextEditingController(text: widget.source?.url);
  late final _selectors = [
    TextEditingController(text: widget.source?.rowSelector ?? ''),
    TextEditingController(text: widget.source?.titleSelector ?? ''),
    TextEditingController(text: widget.source?.linkSelector ?? ''),
    TextEditingController(text: widget.source?.dateSelector ?? ''),
  ];
  late int _color = widget.source?.color ?? NoticeSources.colors.first;
  int _step = 0;
  int _selection = 0;
  bool _saving = false;
  String? _error;
  static const _labels = ['공지 항목 영역', '제목', '링크', '날짜'];
  static const _sampleSelectors = ['.sample-row', 'a', 'a', 'time'];
  static const _sampleTitles = [
    '2026 하반기 동아리 모집 안내',
    '신입 회원 오리엔테이션 안내',
    '10월 활동 일정 및 장소 안내',
  ];

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    for (final field in _selectors) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _next() async {
    if (_step == 0) {
      if (!_form.currentState!.validate()) return;
    } else if (_step == 1) {
      if (_selectors.take(3).any((field) => field.text.trim().isEmpty)) {
        setState(() => _error = '공지 항목 영역, 제목과 링크를 선택해 주세요.');
        return;
      }
      if (_selectors.asMap().entries.any(
        (entry) =>
            entry.value.text.trim().isNotEmpty &&
            entry.value.text.trim() != _sampleSelectors[entry.key],
      )) {
        setState(() => _error = '예시 게시판에서 선택한 위치와 일치하는 셀렉터를 입력해 주세요.');
        return;
      }
    } else {
      setState(() {
        _saving = true;
        _error = null;
      });
      final source =
          (widget.source ??
                  NoticeSource(
                    id: 'custom:${DateTime.now().microsecondsSinceEpoch}',
                    name: '',
                    color: _color,
                  ))
              .copyWith(
                name: _name.text.trim(),
                url: _url.text.trim(),
                color: _color,
                rowSelector: _selectors[0].text.trim(),
                titleSelector: _selectors[1].text.trim(),
                linkSelector: _selectors[2].text.trim(),
                dateSelector: _selectors[3].text.trim(),
              );
      final saved = await widget.sources.put(source);
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context, source.id);
        return;
      }
      setState(() {
        _saving = false;
        _error = widget.sources.error;
      });
      return;
    }
    setState(() {
      _step++;
      _error = null;
    });
  }

  Widget _field(String label, Widget field) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: noticeMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        field,
      ],
    ),
  );

  Widget _registration() => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '어떤 페이지를 추가할까요?',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          '공지 목록이 있는 게시판 주소를 입력해주세요.',
          style: TextStyle(fontSize: 12, color: noticeMuted),
        ),
        const SizedBox(height: 28),
        _field(
          '페이지 이름 / 카테고리 이름 *',
          TextFormField(
            key: const ValueKey('notice-source-name'),
            controller: _name,
            maxLength: 40,
            decoration: noticeInput('예: 동아리 게시판').copyWith(counterText: ''),
            validator: (v) =>
                v == null || v.trim().isEmpty ? '페이지 이름을 입력해 주세요.' : null,
          ),
        ),
        _field(
          '페이지 URL *',
          TextFormField(
            key: const ValueKey('notice-source-url'),
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: noticeInput('https://example.com/notices'),
            validator: (v) => NoticeSources.validUrl(v ?? '')
                ? null
                : 'http 또는 https 목록 페이지 URL을 입력해 주세요.',
          ),
        ),
        const Text(
          '공지 하나의 상세 주소가 아닌, 목록 페이지 주소를 넣어주세요.',
          style: TextStyle(fontSize: 11, color: noticeMuted),
        ),
        const SizedBox(height: 24),
        _field(
          '카테고리 색상',
          NoticeColors(
            color: _color,
            onSelected: (v) => setState(() => _color = v),
          ),
        ),
        const Text(
          '페이지 이름과 색상이 카테고리와 공지 배지에 적용돼요.',
          style: TextStyle(fontSize: 11, color: noticeMuted),
        ),
      ],
    ),
  );

  Widget _locations() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '공지 가져올 위치 설정',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      const Text(
        '위에서 항목을 고른 뒤, 예시 게시판에서 해당 부분을 눌러보세요.',
        style: TextStyle(fontSize: 12, color: noticeMuted),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FC),
          border: Border.all(color: noticeBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 4; i++)
                  ChoiceChip(
                    label: Text(
                      '${_labels[i]} ${i == 3 ? '(선택)' : '*'} ${_selectors[i].text.isEmpty ? '○' : '✓'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _selection == i,
                    onSelected: (_) => setState(() => _selection = i),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '순서대로 선택하면 설정이 쉬워요. 날짜가 없는 게시판은 날짜를 비워두세요.',
              style: TextStyle(fontSize: 11, color: noticeMuted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: noticeBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _url.text,
                style: const TextStyle(fontSize: 11, color: noticeMuted),
              ),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '공지사항',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${_labels[_selection]}${_selection == 2 ? '를' : '을'} 선택해주세요.',
                style: const TextStyle(fontSize: 12, color: noticeBrand),
              ),
            ),
            for (var i = 0; i < 3; i++)
              ListTile(
                key: ValueKey('notice-sample-row-$i'),
                onTap: () => setState(() {
                  _selectors[_selection].text = _sampleSelectors[_selection];
                  if (_selection < 3) _selection++;
                  _error = null;
                }),
                title: Text(
                  _sampleTitles[i],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '2026.09.${30 - i}',
                  style: const TextStyle(fontSize: 11, color: noticeMuted),
                ),
              ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'UI 테스트용 예시 게시판입니다. 입력한 웹사이트에 접속하거나 실제 공지를 수집하지 않습니다.',
                style: TextStyle(fontSize: 11, color: noticeMuted),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      ExpansionTile(
        title: const Text(
          '고급 설정 · CSS 셀렉터 직접 입력',
          style: TextStyle(fontSize: 12, color: noticeMuted),
        ),
        children: [
          for (var i = 0; i < 4; i++)
            _field(
              '${_labels[i]}${i == 3 ? ' (선택)' : ' *'}',
              TextField(
                controller: _selectors[i],
                onChanged: (_) => setState(() {}),
                decoration: noticeInput(_sampleSelectors[i]),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _preview() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '가져올 공지를 확인해주세요',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      const Text(
        '설정한 위치에서 제목과 링크가 올바르게 읽히는지 확인해요.',
        style: TextStyle(fontSize: 12, color: noticeMuted),
      ),
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE9F6F2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '✓ 예시 공지 3개를 확인했어요.',
          style: TextStyle(fontSize: 12, color: Color(0xFF25966C)),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: noticeBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  _sampleTitles[i],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${_selectors[3].text.isEmpty ? '날짜 없음' : '2026.09.${30 - i}'}\n${Uri.parse(_url.text).resolve('/notice/${101 + i}')}',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.8,
                    color: noticeMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        '예시 게시판으로 설정을 검증합니다. 저장된 설정은 이 브라우저에 보관되며, 실제 수집 연결은 별도 구현이 필요합니다.',
        style: TextStyle(fontSize: 11, color: noticeMuted, height: 1.6),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => NoticePanel(
    title: widget.source == null ? '공지 페이지 추가' : '공지 페이지 설정',
    subtitle: '내가 보고 싶은 공지를 한곳에',
    busy: _saving,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Text(
                  '${i < _step ? '✓' : i + 1} ${['페이지 등록', '위치 설정', '미리보기'][i]}',
                  style: TextStyle(
                    fontSize: 11,
                    color: i == _step ? noticeBrand : noticeMuted,
                    fontWeight: i == _step
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        switch (_step) {
          0 => _registration(),
          1 => _locations(),
          _ => _preview(),
        },
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving
            ? null
            : () {
                if (_step == 0) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    _step--;
                    _error = null;
                  });
                }
              },
        child: Text(_step == 0 ? '취소' : '이전'),
      ),
      const Spacer(),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: noticeBrand),
        onPressed: _saving ? null : _next,
        child: Text(
          _saving
              ? '저장 중…'
              : _step == 2
              ? '설정 저장'
              : '다음',
        ),
      ),
    ],
  );
}

class NoticeSourceEditor extends StatefulWidget {
  const NoticeSourceEditor({
    super.key,
    required this.sources,
    required this.source,
  });
  final NoticeSources sources;
  final NoticeSource source;
  @override
  State<NoticeSourceEditor> createState() => _NoticeSourceEditorState();
}

class _NoticeSourceEditorState extends State<NoticeSourceEditor> {
  late final _name = TextEditingController(text: widget.source.name);
  late int _color = widget.source.color;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NoticePanel(
    title: '카테고리 수정',
    width: 430,
    busy: _busy,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '카테고리 이름',
          style: TextStyle(fontSize: 12, color: noticeMuted),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _name,
          readOnly: widget.source.builtIn,
          maxLength: 40,
          decoration: noticeInput('카테고리 이름').copyWith(counterText: ''),
        ),
        const SizedBox(height: 20),
        const Text(
          '카테고리 색상',
          style: TextStyle(fontSize: 12, color: noticeMuted),
        ),
        const SizedBox(height: 12),
        NoticeColors(
          color: _color,
          onSelected: (color) => setState(() => _color = color),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      const Spacer(),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: noticeBrand),
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                final saved = await widget.sources.put(
                  widget.source.copyWith(
                    name: _name.text.trim(),
                    color: _color,
                  ),
                );
                if (!context.mounted) return;
                if (saved) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    _busy = false;
                    _error = widget.sources.error;
                  });
                }
              },
        child: const Text('저장'),
      ),
    ],
  );
}

class NoticeSourceManager extends StatelessWidget {
  const NoticeSourceManager({super.key, required this.sources});
  final NoticeSources sources;

  Future<void> _delete(BuildContext context, NoticeSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text('“${source.name}” 수집처를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await sources.remove(source.id);
    }
  }

  Widget _sourceRow(BuildContext context, NoticeSource source) => LayoutBuilder(
    builder: (context, constraints) {
      final controls = Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          OutlinedButton(
            onPressed: sources.busy
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        NoticeSourceEditor(sources: sources, source: source),
                  ),
            child: Text(source.builtIn ? '색상' : '이름·색상'),
          ),
          if (!source.builtIn)
            OutlinedButton(
              onPressed: sources.busy
                  ? null
                  : () => showDialog<String>(
                      context: context,
                      builder: (_) =>
                          NoticeSourceWizard(sources: sources, source: source),
                    ),
              child: const Text('수집 설정'),
            ),
          TextButton(
            onPressed: source.builtIn || sources.busy
                ? null
                : () => _delete(context, source),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFCF6467),
              textStyle: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 11),
            ),
            child: const Text('삭제'),
          ),
        ],
      );
      final identity = Row(
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: Color(source.color),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  source.builtIn ? '기본 · 색상 변경 가능' : source.url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: noticeMuted),
                ),
              ],
            ),
          ),
        ],
      );
      final toggle = Column(
        children: [
          const Text(
            '공지 수집',
            style: TextStyle(fontSize: 9, color: noticeMuted),
          ),
          Switch.adaptive(
            value: source.enabled,
            activeTrackColor: noticeBrand,
            onChanged: sources.busy
                ? null
                : (value) => sources.put(source.copyWith(enabled: value)),
          ),
        ],
      );
      if (constraints.maxWidth >= 540) {
        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: 9),
            toggle,
            const SizedBox(width: 9),
            controls,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: identity),
              toggle,
            ],
          ),
          controls,
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: sources,
    builder: (context, _) => NoticePanel(
      title: '공지 페이지 설정',
      subtitle: '수정할 페이지를 선택해주세요.',
      width: 630,
      busy: sources.busy,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final builtIn in [true, false]) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                builtIn ? '기본 카테고리' : '추가한 카테고리',
                style: const TextStyle(
                  fontSize: 12,
                  color: noticeMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final source in sources.sources.where(
              (s) => s.builtIn == builtIn,
            )) ...[
              _sourceRow(context, source),
              const Divider(height: 24, color: noticeBorder),
            ],
          ],
          if (sources.error != null)
            Text(
              sources.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
        ],
      ),
    ),
  );
}
