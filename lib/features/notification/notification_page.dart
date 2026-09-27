import 'dart:async';
import 'realtime/realtime_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/base_view.dart';
import '../../core/widgets/notification_bell_button.dart';
import 'notification_scope.dart';
import 'notification_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});
  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String _category = '전체';
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) => BaseView(
    mobileBuilder: (context) => _body(context, 20),
    desktopBuilder: (context) => _body(context, 32),
  );

  Widget _body(BuildContext context, double padding) {
    final service = NotificationScope.of(context);
    final items = service.items
        .where(
          (item) =>
              (_category == '전체' || item.category == _category) &&
              (!_unreadOnly || !item.isRead),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 24, padding, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('알림', style: AppTextStyles.heading1)),
                  const NotificationBellButton(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '읽지 않은 알림 ${service.unreadCount}개',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final category in ['전체', '마감', '강의', '맞춤'])
                    ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('읽지 않음'),
                    selected: _unreadOnly,
                    onSelected: (value) => setState(() => _unreadOnly = value),
                  ),
                  TextButton(
                    onPressed: service.initialized && service.unreadCount > 0
                        ? service.markAllRead
                        : null,
                    child: const Text('모두 읽음'),
                  ),
                  if (kDebugMode)
                    TextButton.icon(
                      icon: const Icon(Icons.add_alert_outlined),
                      label: const Text('테스트 알림'),
                      onPressed: !service.initialized
                          ? null
                          : () {
                              final now = DateTime.now();
                              service.receive(
                                AppNotification(
                                  id: 'debug-${now.microsecondsSinceEpoch}',
                                  title: '테스트 마감 알림',
                                  body: '알림을 누르면 캘린더로 이동해요.',
                                  kind: NotificationKind.deadline,
                                  createdAt: now,
                                ),
                              );
                            },
                    ),
                ],
              ),
              if (service.error != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    if (!service.initialized)
                      TextButton(
                        onPressed: service.initialize,
                        child: const Text('다시 시도'),
                      ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: !service.initialized
              ? Center(
                  child: service.error == null
                      ? const CircularProgressIndicator()
                      : const Text('알림을 불러오지 못했어요.'),
                )
              : items.isEmpty
              ? const Center(child: Text('표시할 알림이 없어요.'))
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(padding, 4, padding, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final date = item.createdAt.toLocal();
                    return Card(
                      margin: EdgeInsets.zero,
                      color: item.isRead
                          ? AppColors.background
                          : AppColors.surface,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: Icon(
                          item.isRead
                              ? Icons.notifications_none
                              : Icons.mark_email_unread_outlined,
                          color: item.isRead
                              ? AppColors.textSecondary
                              : AppColors.primary,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${item.category} · ${date.year}.${date.month}.${date.day} · ${item.isRead ? '읽음' : '읽지 않음'}\n${item.body}',
                        ),
                        isThreeLine: true,
                        onTap: () async {
                          await service.markRead(item.id);
                          if (!context.mounted || service.error != null) return;
                          final realtime = RealtimeScope.maybeOf(context);
                          if (realtime != null) {
                            unawaited(realtime.sendReceipt(item.id, 'opened'));
                          }
                          NotificationNavigation.open(
                            context,
                            item.destinationIndex,
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
