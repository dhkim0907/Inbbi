import unittest
from server import build_message

class PayloadTests(unittest.TestCase):
    def test_valid_payload(self):
        message = build_message({'eventId': 'test-1', 'kind': 'deadline'}, 'fake-token')
        self.assertEqual(message['data']['eventId'], 'test-1')
        self.assertEqual(message['data']['eventType'], 'schedule.reminder')
        self.assertIn('occurredAt', message['data'])
        self.assertEqual(message['notification']['title'], message['data']['title'])

    def test_reject_invalid_payload(self):
        for value in [{}, {'eventId': ''}, {'eventId': 'a', 'kind': 'unknown'}, {'eventId': 'a', 'body': '가' * 1500}]:
            with self.assertRaises(ValueError):
                build_message(value, 'fake-token')


class ServerTests(unittest.TestCase):
    def request(self, authorization, data, fail=False):
        import io
        import json
        import pathlib
        import tempfile
        from server import make_handler
        sent = []
        content = json.dumps(data).encode()
        raw = (f'POST /send HTTP/1.0\r\nAuthorization: {authorization}\r\nContent-Length: {len(content)}\r\n\r\n').encode() + content
        class Connection:
            def __init__(self):
                self.output = bytearray()
            def makefile(self, *args):
                return io.BytesIO(raw)
            def sendall(self, value):
                self.output.extend(value)
        def send(message):
            if fail:
                raise RuntimeError('simulated')
            sent.append(message)
        with tempfile.TemporaryDirectory() as directory:
            token_file = pathlib.Path(directory) / 'token'
            token_file.write_text('fake-test-token')
            handler = make_handler(send, token_file, 'fake-test-key')
            connection = Connection()
            handler(connection, ('127.0.0.1', 1234), object())
            return bytes(connection.output), sent

    def test_authentication_required(self):
        response, sent = self.request('invalid', {'eventId': 'test'})
        self.assertIn(b'401', response)
        self.assertEqual(sent, [])

    def test_authorized_send(self):
        response, sent = self.request('Bearer fake-test-key', {'eventId': 'test'})
        self.assertIn(b'200', response)
        self.assertEqual(len(sent), 1)
        self.assertNotIn(b'fake-test-token', response)

    def test_fcm_failure_is_reported_without_secrets(self):
        response, sent = self.request('Bearer fake-test-key', {'eventId': 'test'}, fail=True)
        self.assertIn(b'502', response)
        self.assertNotIn(b'fake-test-token', response)

class AdminSdkTests(unittest.TestCase):
    def test_native_and_web_message_serialization(self):
        import json
        from server import create_fcm_message
        value = create_fcm_message(build_message({'eventId': 'test-1'}, 'fake-token'))
        encoded = json.loads(str(value))
        self.assertEqual(encoded['webpush']['notification']['tag'], 'test-1')
        self.assertEqual(encoded['apns']['payload']['aps']['content-available'], 1)
        self.assertEqual(encoded['data']['eventId'], 'test-1')

if __name__ == '__main__':
    unittest.main()
