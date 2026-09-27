# 앱 외부 알림: 웹·iOS

## 구현과 표시 정책

FCM 서버 푸시를 사용한다. 로컬 예약 알림은 구현하지 않는다.

- 설정의 **앱 외부 알림** 스위치에서 권한 요청과 수신 활성화/비활성화를 수행한다.
- 포그라운드: 내부 목록과 배지 갱신. 시스템 배너는 추가 표시하지 않는다.
- 백그라운드/일반 종료: 서버의 `notification + data` 메시지를 운영체제/브라우저가 표시한다. FCM data는 WebSocket과 같은 eventId·version을 문자열 값으로 전달한다.
- 클릭: 앱 초기화 후 관련 탭으로 이동하며 읽음 처리한다. 로그인 화면에서는 이동을 보류하고 메인 화면 진입 시 처리한다. 현재 로그인은 목업이다.
- iOS 백그라운드 수신함은 SharedPreferences의 이벤트별 키, 웹은 IndexedDB를 사용한다. 앱 복귀 시 내부 목록에 합친다. 읽음 목록 전체를 백그라운드에서 덮어쓰지 않는다.
- 같은 `eventId`의 내부 목록 등록은 한 번이며 높은 `version`만 갱신한다. 웹 알림은 같은 ID를 tag로 사용한다. iOS 시스템 배너의 재전송 중복까지 차단하는 것은 아니므로 서버에서 중복 발송을 방지해야 한다.
- 끄기는 FCM 토큰 삭제 및 네이티브 자동 초기화 비활성화로 처리한다. 실패는 오류로 표시한다. 이미 전달되었거나 전송 중인 시스템 알림을 회수하지는 않는다.
- 자동 로그인 해제 시 활성화된 푸시도 해제한다. 계정별 서버 기기 등록 API는 아직 없다.
- Firebase 설정이 없으면 앱은 정상 실행되며 외부 알림 스위치가 비활성화된다.

## Firebase 설정

개발용 Firebase 프로젝트에 웹과 iOS 앱을 각각 등록한다. 플랫폼마다 Firebase APP_ID와 API_KEY 등이 다를 수 있으므로 설정 파일을 따로 만든다. `config/firebase.example.json`을 복사해 다음 두 파일을 준비한다. `.local.json`은 Git에서 제외된다.

- `config/firebase.web.local.json`: 웹 Firebase 공개 설정 + Web Push 인증서의 VAPID 공개 키.
- `config/firebase.ios.local.json`: iOS 앱의 공개 설정 + Bundle ID. VAPID 키는 빈 문자열.

Firebase 공개 클라이언트 설정은 앱/웹에 포함된다. **서버 서비스 계정 JSON, APNs 비밀 키는 이 파일에 넣지 않는다.**

### 웹

```sh
python3 tool/configure_push.py config/firebase.web.local.json
flutter run -d chrome --web-port 8080 --dart-define-from-file=config/firebase.web.local.json
```

생성기는 `web/firebase-config.js`에 공개 설정만 기록한다. 플랫폼별 dart-define과 이 파일의 프로젝트가 일치해야 한다. 배포 시에도 먼저 생성기를 실행하고 같은 설정으로 `flutter build web`을 실행한다. 현재 FCM의 기본 서비스 워커 경로를 사용하므로 **도메인 루트(`/`)에서 제공**한다. 테스트는 localhost, 배포는 HTTPS에서 진행한다. 서비스 워커 스크립트와 Firebase CDN 접근을 허용한다.

설정 화면에서 사용자가 스위치를 눌러 브라우저 권한을 허용해야 한다. 토큰은 브라우저 프로필·사이트별로 다르다. 우선 데스크톱 Chrome에서 확인하고 Safari 등 다른 브라우저는 별도로 검증한다. 브라우저 완전 종료 시 전달 동작은 브라우저와 OS 설정에 따라 다르다.

### iOS

1. Firebase에 등록한 Bundle ID를 Xcode Runner의 Bundle Identifier와 맞춘다.
2. Apple Developer 팀과 Push Notifications가 가능한 프로비저닝을 설정한다.
3. Firebase 프로젝트의 Cloud Messaging 설정에 APNs 인증 키를 업로드한다.
4. Xcode의 Signing & Capabilities에서 Push Notifications와 Background Modes > Remote notifications를 확인한다. 저장소에 entitlements와 백그라운드 설정을 추가했다. `aps-environment`는 개발용이며 배포 서명 시 프로비저닝에 맞는 환경을 확인한다.
5. 실제 테스트 기기에서 실행한다.

```sh
flutter run -d <ios-device-id> --dart-define-from-file=config/firebase.ios.local.json
```

명시적인 FirebaseOptions로 앱을 초기화하므로 앱 구성에 서비스 계정 키를 넣지 않는다. 설치된 Firebase SDK의 최소 요구사항에 맞춰 iOS 최소 버전을 15.0으로 변경했다. FlutterFire의 method swizzling을 비활성화하지 않는다.

## 테스트 서버 실행

`tool/push_server/server.py`는 **localhost에만 바인딩하는 단일 테스트 기기용 HTTP 서버**다. 실시간 서버 인증 연결이 없을 때는 앱에서 서버로 토큰을 자동 등록하지 않는다. 실시간 서비스에 연결하면 [프로토콜 문서](notification_protocol.md)의 기기 API를 사용한다. 설정의 개발 전용 **테스트 수신 토큰 복사**로 복사한 값을 `.secrets/fcm-token.txt`에 저장한다. 토큰이 갱신되거나 알림을 껐다 켰다면 다시 복사한다. 토큰은 앱 화면이나 로그에 출력하지 않는다.

서버는 같은 Firebase 프로젝트의 Application Default Credentials를 사용한다. 서비스 계정 파일은 저장소 외부 또는 Git 제외된 `.secrets/`에 보관한다. FCM API 사용 및 발송 권한을 설정한다.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tool/push_server/requirements.txt
mkdir -p .secrets
python3 -c "import secrets,pathlib; pathlib.Path('.secrets/push-api-key.txt').write_text(secrets.token_urlsafe(32))"
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/test-service-account.json
export TEST_PUSH_API_KEY_FILE=.secrets/push-api-key.txt
export TEST_PUSH_TOKEN_FILE=.secrets/fcm-token.txt
.venv/bin/python tool/push_server/server.py
```

다른 터미널에서 같은 API 키 파일 환경 변수를 지정하고 발송한다.

```sh
export TEST_PUSH_API_KEY_FILE=.secrets/push-api-key.txt
.venv/bin/python tool/push_server/send_test.py test-notice-001
```

테스트 요청은 `POST /send`, `Authorization: Bearer <로컬 테스트 API 키>`를 사용한다. 본문은 아래 형식이며, 대상 토큰은 서버가 파일에서 읽는다. 임의 대상 토큰을 요청으로 받지 않는다.

```json
{"eventId":"test-deadline-001","kind":"deadline","title":"테스트 일정 마감","body":"알림 선택 시 캘린더로 이동합니다."}
```

`kind`는 `deadline`(캘린더), `course`(강의), `notice`(공지) 중 하나다. 서버가 `createdAt`을 UTC로 넣고 제목·내용을 notification과 data 양쪽에 넣는다. 서버의 성공 응답은 FCM의 **접수**이며 실제 기기 수신 성공을 의미하지 않는다. 서버 테스트는 실제 발송을 하지 않는 대체 발송 함수를 사용한다.

## 검증 시나리오와 제약

| 조건 | 기대 결과 |
|---|---|
| 앱/웹 탭이 활성 상태 | 내부 목록·배지 갱신, 외부 배너 중복 없음 |
| 다른 앱/탭으로 전환 후 발송 | 시스템 알림 표시, 선택 시 대상 탭 이동 |
| 일반 종료 후 알림 선택 | 시작·로그인 이후 대상 탭 이동 |
| 권한 거부 | 오류 안내, 수신 활성화되지 않음 |
| 스위치 끄기 | 토큰 무효화, 기존 토큰으로 새 발송 실패 가능 |
| 같은 이벤트 ID로 재수신 | 내부 목록은 한 개, 기존 읽음 상태 유지 |
| 저장 오류 후 복귀 | 수신함을 지우지 않고 이후 다시 반영 |
| 네트워크 오류 | 설정 실패 표시, 재시도 가능 |

OS는 모든 백그라운드 콜백 실행을 보장하지 않는다. 특히 iOS 앱 전환기에서 강제 종료한 뒤에는 백그라운드 메시지 처리를 위해 앱을 다시 열어야 한다. 콜백이 실행되지 않고 알림도 선택하지 않았다면 내부 목록에 누락될 수 있다. 이를 완전히 보완하려면 서버 알림 조회 API가 추가로 필요하다. 브라우저 사이트 데이터 삭제 시 로컬 수신함과 목록은 사라진다.

일정 변경·취소에 따른 마감 푸시 예약 갱신, 실제 일정·공지 서비스 연결, 계정별 토큰 등록·해제 API는 아직 구현하지 않았다. 이번 테스트 서버는 요청 즉시 한 건을 발송한다.

## 검증 기록

- `flutter analyze`: 통과.
- `flutter test`: 16개 통과. 내부 알림, 푸시 권한·토큰·수신함·실패 복구·클릭 이동, 모바일/데스크톱 설정 UI 포함.
- `.venv/bin/python -m unittest discover -s tool/push_server -p 'test_*.py'`: 6개 통과. 인증, 발송 오류, 페이로드, 실제 Admin SDK 메시지 직렬화 포함. 실제 FCM 전송은 하지 않았다.
- `flutter build web`: 성공. 웹 JavaScript 서비스 워커의 실제 브라우저 수신 실행은 미검증. Cupertino 아이콘 폰트 관련 빌드 경고가 있었다.
- `flutter build ios --no-codesign`: 성공. 실제 기기 설치·서명·APNs 수신은 미검증.
- 서버 테스트 환경은 Python 3.9.6이며 Google 인증 SDK의 Python 지원 종료 경고와 LibreSSL 호환성 경고가 있었다. 실제 서버 실행 환경은 Python 3.11 이상과 OpenSSL을 사용하는 환경으로 준비한다.
- iOS의 최소 지원 버전은 Firebase SDK 요구사항에 맞춘 15.0이다.
- 실제 Firebase 프로젝트, APNs 서명, 대상 기기 토큰이 제공되지 않아 실제 전달은 미검증이다.
- 테스트 시 플랫폼/OS·브라우저 버전, 앱 상태, 이벤트 ID, 기대/실제 결과를 기록한다. 토큰과 비밀 키는 기록하지 않는다.

공식 문서:
- https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- https://firebase.google.com/docs/cloud-messaging/send/admin-sdk
