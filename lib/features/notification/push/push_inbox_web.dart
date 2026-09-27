import 'dart:async';
import 'dart:js_interop';

@JS('inbbiPushInbox.load')
external JSPromise<JSAny?> _load();
@JS('inbbiPushInbox.remove')
external JSPromise<JSAny?> _remove(JSString id);
@JS('inbbiPushInbox.save')
external JSPromise<JSAny?> _save(JSAny data);

Future<List<Map<String, dynamic>>> loadPendingPushes() async {
  final values = (await _load().toDart).dartify() as List;
  return values
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();
}

Future<void> removePendingPush(String id) async {
  await _remove(id.toJS).toDart;
}

Future<void> savePendingPush(Map<String, dynamic> data) async {
  await _save(data.jsify()!).toDart;
}

@JS('inbbiPushInbox.onOpened')
external set _onOpened(JSFunction? callback);
Stream<void> watchPushOpened() {
  late StreamController<void> controller;
  controller = StreamController<void>(
    onListen: () {
      _onOpened = (() {
        controller.add(null);
      }).toJS;
    },
    onCancel: () {
      _onOpened = null;
    },
  );
  return controller.stream;
}
