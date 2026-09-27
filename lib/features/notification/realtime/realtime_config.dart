class RealtimeConfig {
  static const socketUrl = String.fromEnvironment('NOTIFICATION_WS_URL');
  static const apiUrl = String.fromEnvironment('NOTIFICATION_API_URL');
  static bool get configured {
    final ws = Uri.tryParse(socketUrl);
    final api = Uri.tryParse(apiUrl);
    return ws?.scheme == 'wss' &&
        api?.scheme == 'https' &&
        ws?.host.isNotEmpty == true &&
        api?.host.isNotEmpty == true;
  }
}
