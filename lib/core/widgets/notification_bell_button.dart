import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _PopoverItem {
  const _PopoverItem({
    required this.title,
    required this.meta,
    this.urgent = false,
  });

  final String title;
  final String meta;
  final bool urgent;
}

/// 모든 페이지 상단 헤더에서 공통으로 쓰이는 알림 벨 버튼.
/// 누르면 버튼 바로 아래에 알림 요약 팝오버가 뜬다 (모바일/데스크톱 공통).
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  static const Color _brandColor = Color(0xFF346CB2);

  // TODO: 실제 알림 데이터로 교체
  static const int _dueCount = 2;
  static const int _notEnrolledCount = 1;
  static const int _todoCount = 4;
  static const List<_PopoverItem> _items = [
    _PopoverItem(
      title: 'SW융합 프로젝트 최종 발표 준비',
      meta: '오늘 23:59 마감',
      urgent: true,
    ),
    _PopoverItem(title: '인터넷프로그래밍 9주차 강의', meta: '수강률 0% · 6시간 남음'),
    _PopoverItem(title: '장학금 신청 안내 확인', meta: '학과공지 · D-3'),
  ];

  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _toggle() => _entry == null ? _open() : _close();

  void _open() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: Container(color: _brandColor.withValues(alpha: 0.12)),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 12),
            child: const _NotificationPopover(
              dueCount: _dueCount,
              notEnrolledCount: _notEnrolledCount,
              todoCount: _todoCount,
              items: _items,
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _toggle,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: _brandColor,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.notifications, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

class _NotificationPopover extends StatefulWidget {
  const _NotificationPopover({
    required this.dueCount,
    required this.notEnrolledCount,
    required this.todoCount,
    required this.items,
  });

  final int dueCount;
  final int notEnrolledCount;
  final int todoCount;
  final List<_PopoverItem> items;

  @override
  State<_NotificationPopover> createState() => _NotificationPopoverState();
}

class _NotificationPopoverState extends State<_NotificationPopover> {
  static const Color _brandColor = Color(0xFF346CB2);
  static const Color _urgentColor = Color(0xFFDC2626);
  static const Color _metaColor = Color(0xFF64748B);
  static const Color _readBackgroundColor = Color(0xFFF3F4F6);

  final Set<int> _readIndices = {};

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxHeight: 480),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFDCE7FA),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '오늘 마감 ${widget.dueCount}개 · 미수강 ${widget.notEnrolledCount}개',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _brandColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '오늘 해야 할 일',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.todoCount}개',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < widget.items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _readIndices.add(i)),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _readIndices.contains(i)
                            ? _readBackgroundColor
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.items[i].title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.items[i].meta,
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.items[i].urgent
                                  ? _urgentColor
                                  : _metaColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
