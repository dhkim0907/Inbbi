"""파일 기반 인증으로 로컬 테스트 서버에 요청한다. 토큰/인증키를 출력하지 않는다."""
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

key = pathlib.Path(os.environ['TEST_PUSH_API_KEY_FILE']).read_text().strip()
event_id = sys.argv[1] if len(sys.argv) > 1 else 'test-notice-001'
request = urllib.request.Request(
    'http://127.0.0.1:' + os.environ.get('PORT', '8765') + '/send',
    data=json.dumps({'eventId': event_id, 'kind': 'notice', 'title': '테스트 공지', 'body': '서버 푸시 수신을 확인해 주세요.'}).encode(),
    headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'},
)
try:
    with urllib.request.urlopen(request, timeout=20) as response:
        print('FCM 발송 접수 완료. 기기에서 표시와 클릭 이동을 확인하세요.')
except urllib.error.URLError:
    sys.exit('발송 실패. 서버 상태와 로컬 설정을 확인하세요.')
