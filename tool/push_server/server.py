"""로컬 테스트 전용 FCM 발송 서버. 실제 발송은 POST /send에서만 실행한다."""
import datetime
import hmac
import json
import os
import pathlib
from http.server import BaseHTTPRequestHandler, HTTPServer


def build_message(data, token):
    event_id = data.get('eventId')
    kind = data.get('kind', 'notice')
    title = data.get('title', '테스트 공지')
    body = data.get('body', '서버에서 보낸 테스트 알림입니다.')
    if not isinstance(event_id, str) or not 1 <= len(event_id) <= 200:
        raise ValueError('eventId required')
    if kind not in ('deadline', 'course', 'notice', 'other'):
        raise ValueError('invalid kind')
    if not isinstance(title, str) or not 1 <= len(title) <= 200:
        raise ValueError('invalid title')
    if not isinstance(body, str) or len(body) > 2000:
        raise ValueError('invalid body')
    event_type = data.get('eventType') or {'deadline': 'schedule.reminder', 'course': 'course.updated', 'notice': 'notice.created', 'other': 'other.created'}[kind]
    target = data.get('target') or {'type': event_type.split('.')[0], 'id': 'test-001'}
    if (not isinstance(event_type, str) or not isinstance(target, dict)
            or not isinstance(target.get('type'), str)
            or not isinstance(target.get('id'), str)
            or not isinstance(data.get('deepLink', ''), str)):
        raise ValueError('invalid event')
    version = data.get('version', 1)
    if not isinstance(version, int) or version < 1:
        raise ValueError('invalid version')
    payload = {
        'type': 'notification', 'eventId': event_id, 'eventType': event_type,
        'version': str(version), 'title': title, 'body': body,
        'target': json.dumps(target),
        'deepLink': data.get('deepLink', ''),
        'occurredAt': datetime.datetime.now(datetime.timezone.utc).isoformat().replace('+00:00', 'Z'),
    }
    # FCM 전체 페이로드 한도를 넘기지 않도록 UTF-8 바이트를 보수적으로 제한한다.
    if len(json.dumps(payload, ensure_ascii=False).encode()) > 1800:
        raise ValueError('payload too large')
    return {'token': token, 'data': payload, 'notification': {'title': title, 'body': body}}


def make_handler(send, token_file, api_key):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass  # Authorization 헤더, 토큰, 원문 메시지를 로그에 기록하지 않는다.

        def reply(self, status, body):
            content = json.dumps(body).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        def do_POST(self):
            if self.path != '/send':
                return self.reply(404, {'error': 'not_found'})
            auth = self.headers.get('Authorization', '')
            if not hmac.compare_digest(auth.encode(), ('Bearer ' + api_key).encode()):
                return self.reply(401, {'error': 'unauthorized'})
            try:
                size = int(self.headers.get('Content-Length', '0'))
                if not 0 < size <= 8192:
                    raise ValueError('invalid length')
                data = json.loads(self.rfile.read(size))
                if not isinstance(data, dict):
                    raise ValueError('invalid body')
                token = pathlib.Path(token_file).read_text().strip()
                if not token:
                    raise ValueError('missing token')
                message = build_message(data, token)
            except (ValueError, OSError):
                return self.reply(400, {'error': 'invalid_request_or_target'})
            try:
                send(message)
            except Exception:
                return self.reply(502, {'error': 'fcm_send_failed'})
            self.reply(200, {'accepted': True, 'eventId': data['eventId']})
    return Handler


def create_fcm_message(value):
    from firebase_admin import messaging
    return messaging.Message(
        token=value['token'], data=value['data'],
        notification=messaging.Notification(**value['notification']),
        apns=messaging.APNSConfig(headers={'apns-priority': '10'},
            payload=messaging.APNSPayload(messaging.Aps(sound='default', content_available=True))),
        webpush=messaging.WebpushConfig(notification=messaging.WebpushNotification(tag=value['data']['eventId'])),
    )


def main():
    # ADC는 GOOGLE_APPLICATION_CREDENTIALS 등 서버 환경에서만 읽는다.
    import firebase_admin
    from firebase_admin import messaging
    api_key = pathlib.Path(os.environ['TEST_PUSH_API_KEY_FILE']).read_text().strip()
    if len(api_key) < 32:
        raise ValueError('Use an API key of at least 32 characters')
    token_file = os.environ['TEST_PUSH_TOKEN_FILE']
    firebase_admin.initialize_app()

    def send(value):
        messaging.send(create_fcm_message(value))

    server = HTTPServer(('127.0.0.1', int(os.environ.get('PORT', '8765'))), make_handler(send, token_file, api_key))
    server.timeout = 10
    print('테스트 푸시 서버 준비: localhost /send (발송 요청 대기)')
    server.serve_forever()


if __name__ == '__main__':
    main()
