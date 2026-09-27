"""로컬 dart-define 설정에서 웹 서비스 워커용 공개 설정을 생성한다."""
import json
import pathlib
import sys


def configure(path):
    config = json.loads(pathlib.Path(path).read_text())
    fields = {
        'apiKey': 'FIREBASE_API_KEY', 'appId': 'FIREBASE_APP_ID',
        'messagingSenderId': 'FIREBASE_MESSAGING_SENDER_ID',
        'projectId': 'FIREBASE_PROJECT_ID',
    }
    public = {key: config[value] for key, value in fields.items()}
    if not all(isinstance(value, str) and value for value in public.values()):
        raise ValueError('Firebase 설정이 비어 있습니다.')
    target = pathlib.Path(__file__).resolve().parent.parent / 'web/firebase-config.js'
    target.write_text('self.inbbiFirebaseConfig = ' + json.dumps(public) + ';\n')


if __name__ == '__main__':
    try:
        configure(sys.argv[1])
        print('웹 푸시 공개 설정 생성 완료')
    except (IndexError, KeyError, ValueError, OSError):
        sys.exit('사용법: python3 tool/configure_push.py config/firebase.web.local.json (유효한 Firebase 설정 필요)')
