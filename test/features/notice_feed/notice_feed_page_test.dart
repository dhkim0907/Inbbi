import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbbi/core/theme/app_theme.dart';
import 'package:inbbi/features/notice_feed/notice_feed_page.dart';
import 'package:inbbi/features/notice_feed/notice_sources.dart';
import 'package:inbbi/features/notification/notification_scope.dart';
import 'package:inbbi/features/notification/notification_service.dart';

import 'notice_sources_test.dart' show MemoryNoticeStorage;
import '../../support/ui_review.dart';

class _Storage implements NotificationStorage {
  @override
  Future<String?> load() async => null;
  @override
  Future<void> save(String value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadReviewFonts);
  for (final width in [390.0, 839.0, 840.0, 1207.0]) {
    testWidgets('공지 검색·분류·빈 목록·복귀 및 긴 검색어 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sources = NoticeSources(MemoryNoticeStorage());
      addTearDown(sources.dispose);
      await sources.initialize();
      final notifications = NotificationService(_Storage());
      addTearDown(notifications.dispose);
      await notifications.initialize();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        NotificationScope(
          service: notifications,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: RepaintBoundary(
              key: boundary,
              child: NoticeFeedPage(sources: sources),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if ([390.0, 1207.0].contains(width)) {
        await captureReview(tester, boundary, 'notice-${width.toInt()}');
      }
      await tester.tap(find.byKey(const ValueKey('notice-filter:school')));
      await tester.pumpAndSettle();
      expect(find.text('학습지원센터 비교과 프로그램 모집'), findsOneWidget);
      expect(find.text('2026-1 소프트웨어융합공학과 장학금 신청 안내'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('notice-search')),
        '찾을 수 없는 공지' * 20,
      );
      await tester.pump();
      expect(find.text('표시할 공지가 없어요.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('notice-search')),
        '학사일정',
      );
      await tester.pump();
      expect(find.text('인하대학교 학사일정 변경 안내'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('notice-search')), '');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('notice-filter:all')));
      await tester.pumpAndSettle();
      expect(find.text('2026-1 소프트웨어융합공학과 장학금 신청 안내'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('수집처 등록 흐름·필수 입력·날짜 생략·저장 및 설정 열기 너비 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryNoticeStorage();
      final sources = NoticeSources(storage);
      addTearDown(sources.dispose);
      await sources.initialize();
      final notifications = NotificationService(_Storage());
      addTearDown(notifications.dispose);
      await notifications.initialize();
      final review = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: review,
          child: NotificationScope(
            service: notifications,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: NoticeFeedPage(sources: sources),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('공지 페이지 추가'));
      await tester.pumpAndSettle();
      await captureReview(tester, review, 'notice-register-${width.toInt()}');
      await tester.tap(find.text('다음'));
      await tester.pump();
      expect(find.text('페이지 이름을 입력해 주세요.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('notice-source-name')),
        '테스트 게시판',
      );
      await tester.enterText(
        find.byKey(const ValueKey('notice-source-url')),
        'https://example.com/new',
      );
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pump();
      expect(find.text('공지 항목 영역, 제목과 링크를 선택해 주세요.'), findsOneWidget);
      await captureReview(tester, review, 'notice-locations-${width.toInt()}');
      final row = find.byKey(const ValueKey('notice-sample-row-0'));
      for (var i = 0; i < 3; i++) {
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pump();
      }
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.textContaining('날짜 없음'), findsNWidgets(3));
      await captureReview(tester, review, 'notice-preview-${width.toInt()}');
      await tester.tap(find.text('설정 저장'));
      await tester.pumpAndSettle();
      expect(sources.sources.last.name, '테스트 게시판');
      expect(sources.sources.last.dateSelector, isEmpty);
      expect(storage.value, isNotNull);
      expect(find.text('테스트 게시판 · 신입 회원 모집 안내'), findsOneWidget);
      await tester.tap(find.byTooltip('수집처 설정'));
      await tester.pumpAndSettle();
      expect(find.text('공지 페이지 설정'), findsOneWidget);
      expect(find.text('기본 카테고리'), findsOneWidget);
      await captureReview(tester, review, 'notice-manage-${width.toInt()}');
      expect(tester.takeException(), isNull);
    });
  }
}
