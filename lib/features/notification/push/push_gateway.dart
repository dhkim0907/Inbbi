import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'push_config.dart';
import 'push_inbox.dart';
import 'push_payload.dart';

enum PushPermission { allowed, denied, notDetermined }

abstract interface class PushGateway {
  Future<void> initialize();
  Stream<Map<String, dynamic>> get messages;
  Stream<Map<String, dynamic>> get openedMessages;
  Stream<String> get tokenRefresh;
  Future<Map<String, dynamic>?> initialMessage();
  Future<PushPermission> permission({bool request = false});
  Future<String?> enable();
  Future<void> disable();
}

@pragma('vm:entry-point')
Future<void> firebasePushBackgroundHandler(RemoteMessage message) async {
  // 시스템 표시를 중복 호출하지 않는다. UI와 별도인 수신함만 저장한다.
  if (parsePush(message.data) == null) return;
  try {
    await savePendingPush(message.data);
  } catch (_) {
    // 배경 실행에서 원문 메시지/토큰을 로그에 남기지 않는다.
  }
}

class FirebasePushGateway implements PushGateway {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  @override
  Future<void> initialize() async {
    await Firebase.initializeApp(options: PushConfig.options);
    if (!await _messaging.isSupported()) throw UnsupportedError('push');
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebasePushBackgroundHandler);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    }
  }

  @override
  Stream<Map<String, dynamic>> get messages =>
      FirebaseMessaging.onMessage.map((message) => message.data);
  @override
  Stream<Map<String, dynamic>> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);
  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;
  @override
  Future<Map<String, dynamic>?> initialMessage() async =>
      kIsWeb ? null : (await _messaging.getInitialMessage())?.data;
  @override
  Future<PushPermission> permission({bool request = false}) async {
    final settings = request
        ? await _messaging.requestPermission()
        : await _messaging.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PushPermission.allowed,
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently => PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
    };
  }

  @override
  Future<String?> enable() async {
    if (!kIsWeb) await _messaging.setAutoInitEnabled(true);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // APNs 토큰 등록은 비동기이므로 잠시 기다린 뒤 재시도 가능한 오류로 처리한다.
      for (var i = 0; i < 10; i++) {
        if (await _messaging.getAPNSToken() != null) break;
        if (i == 9) throw StateError('APNs unavailable');
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    if (kIsWeb && PushConfig.vapidKey.isEmpty) {
      throw StateError('VAPID unavailable');
    }
    return _messaging.getToken(vapidKey: kIsWeb ? PushConfig.vapidKey : null);
  }

  @override
  Future<void> disable() async {
    if (!kIsWeb) await _messaging.setAutoInitEnabled(false);
    await _messaging.deleteToken();
  }
}
