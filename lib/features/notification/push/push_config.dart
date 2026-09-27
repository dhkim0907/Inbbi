import 'package:firebase_core/firebase_core.dart';

/// 플랫폼별 --dart-define-from-file 값. 서버 서비스 계정 키는 넣지 않는다.
class PushConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');
  static bool get configured =>
      [apiKey, appId, senderId, projectId].every((v) => v.isNotEmpty);
  static FirebaseOptions get options => const FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    iosBundleId: String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'com.example.inbbi',
    ),
  );
}
