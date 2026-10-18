# Inbbi

인삐(Inbbi)는 I-Class와 학사 정보를 한곳에서 관리하기 위한 Flutter 애플리케이션입니다. Android·iOS·웹을 대상으로 캘린더, 공지, 강의, 알림 화면을 제공합니다.

현재 저장소에는 Flutter 클라이언트와 로컬 푸시 테스트 서버가 포함되어 있습니다. 인증·캘린더·실시간 알림용 앱 서버 구현은 포함되어 있지 않습니다.

## 주요 기능과 개발 상태

| 영역 | 현재 구성 |
|---|---|
| 홈·강의 | 대시보드와 강의 관리 화면 |
| 캘린더 | 월별 조회, 날짜 선택, 일정·할일 추가, 상세 조회·수정·삭제, 개발용 샘플 일정 |
| Google 캘린더 | 기본 캘린더 조회·쓰기, 계정 연결·해제, 앱 서버 연결용 클라이언트 |
| 공지 | 공지 피드 화면과 수집처 설정 UI |
| 앱 내부 알림 | 목록·필터·읽음 처리·배지, 로컬 저장, 이벤트 ID·버전 기반 중복 처리 |
| 외부·실시간 알림 | FCM 푸시, WebSocket 수신, HTTP 목록 복구·수신 확인용 클라이언트 |
| 인증·설정 | 테스트 인증 API 연결, 세션 복원·갱신, 데이터 수집·알림 설정 |

화면은 너비 840 논리 픽셀을 기준으로 전환합니다. 모바일에서는 하단 내비게이션, 데스크톱에서는 왼쪽 내비게이션 레일을 사용합니다.

실제 학사·공지 수집 서비스, 앱 서버 저장, Google 계정 연동, 기기 푸시 전달은 외부 서버·계정·플랫폼 설정에 따라 별도 검증이 필요합니다. 로컬 예약 알림은 구현되어 있지 않습니다. 외부 알림 설정과 검증 절차는 웹·iOS를 중심으로 문서화되어 있습니다.

## 개발 환경

- Dart SDK `^3.12.2`와 호환되는 Flutter SDK
- 웹 실행: Chrome
- Android 빌드·실행: Android SDK와 에뮬레이터 또는 기기
- iOS 빌드·실행: macOS, Xcode 및 필요한 서명 설정
- 푸시 테스트 서버 실행 시: Python 3.11 이상 권장, 별도 가상 환경

주요 의존성은 `google_sign_in`, `http`, `firebase_core`, `firebase_messaging`, `web_socket_channel`, `shared_preferences`, `flutter_secure_storage`, `connectivity_plus`입니다. 정확한 버전은 [pubspec.yaml](pubspec.yaml)과 [pubspec.lock](pubspec.lock)을 참고합니다.

## 빠른 시작

저장소 루트에서 실행합니다.

```sh
flutter pub get
flutter run -d chrome
```

기본 디버그 실행에는 `[샘플]` 제목의 캘린더 일정이 표시됩니다. 샘플은 서버나 Google에 저장되지 않으며 앱 재실행 시 초기화됩니다. 샘플을 숨기려면 다음과 같이 실행합니다.

```sh
flutter run -d chrome --dart-define=CALENDAR_SAMPLE_DATA=false
```

서버 주소가 없으면 로그인 버튼으로 서버 인증 없이 앱에 진입합니다. 실제 서버 일정과 인증 기능을 확인하려면 테스트 서버 설정이 필요합니다. Firebase 설정이 없어도 앱은 실행되며 외부 알림 스위치는 비활성화됩니다.

다른 실행 대상은 `flutter devices`로 확인합니다.

## 연동 설정

### 앱 서버·Google 캘린더

```sh
flutter run -d chrome --web-port 8080 \
  --dart-define=CALENDAR_API_URL=https://your-test-server.example/ \
  --dart-define=GOOGLE_WEB_CLIENT_ID=your-web-client-id
```

| 설정 | 용도 |
|---|---|
| `CALENDAR_API_URL` | 인증·캘린더 앱 서버의 기본 URL. HTTPS를 사용하고 경로를 `/`로 끝냅니다. 디버그에서는 localhost·127.0.0.1의 HTTP도 허용합니다. |
| `GOOGLE_WEB_CLIENT_ID` | Google 웹 OAuth 클라이언트 ID |
| `GOOGLE_IOS_CLIENT_ID` | iOS용 Google OAuth 클라이언트 ID |
| `CALENDAR_SAMPLE_DATA` | 디버그 샘플 일정 표시 여부. 기본값은 `true`이며 릴리스·프로파일에는 샘플이 포함되지 않습니다. |

Google 연결은 설정 화면에서 시작합니다. Google Cloud의 Calendar API, OAuth 동의 화면·테스트 사용자, 웹 승인 원본 또는 플랫폼별 앱 설정을 준비해야 합니다. 위 웹 실행 예시에서는 `http://localhost:8080`을 승인 원본에 맞춰 등록합니다.

서버 주소가 설정되면 로그인 화면은 테스트 인증 API를 호출합니다. 앱 전용 일정 저장과 서버를 통한 Google 연결·일정 조작에는 해당 API를 구현한 서버가 필요합니다. API 계약과 플랫폼별 설정은 [캘린더 개발 문서](docs/calendar_development.md)를 참고합니다.

### Firebase 푸시·실시간 알림

[config/firebase.example.json](config/firebase.example.json)을 복사해 플랫폼별 로컬 설정 파일을 준비합니다. 웹 예시는 다음과 같습니다.

```sh
cp config/firebase.example.json config/firebase.web.local.json
# 복사한 파일에 테스트 프로젝트의 웹 Firebase 설정과 VAPID 공개 키를 입력합니다.
python3 tool/configure_push.py config/firebase.web.local.json
flutter run -d chrome --web-port 8080 \
  --dart-define-from-file=config/firebase.web.local.json
```

`configure_push.py`는 웹 서비스 워커가 사용할 `web/firebase-config.js`를 생성합니다. 웹 푸시는 localhost 또는 HTTPS에서 테스트하며, 현재 서비스 워커 구성은 도메인 루트(`/`) 제공을 전제로 합니다.

실시간 알림 서버를 사용할 때는 로컬 설정의 `NOTIFICATION_WS_URL`에 `wss://` 주소, `NOTIFICATION_API_URL`에 `https://` 기본 URL을 지정합니다. HTTP API 기본 URL의 경로는 `/`로 끝냅니다.

iOS의 Firebase·APNs·서명 설정, 로컬 테스트 서버 실행과 발송 절차는 [푸시 알림 문서](docs/push_notifications.md), WebSocket·HTTP 서버 계약은 [알림 프로토콜](docs/notification_protocol.md)을 참고합니다.

`config/*.local.json`, `.secrets/`, `.venv/`는 Git에서 제외됩니다. 테스트 계정과 데이터를 사용하고, 인증 토큰·서비스 계정 키·APNs 비밀 키를 코드나 로그에 기록하지 않습니다. Firebase 공개 클라이언트 설정에 서버 비밀 키를 넣지 않습니다.

## 프로젝트 구조

```text
lib/
├── main.dart                 # Flutter 초기화·폰트 로딩·앱 실행
├── app.dart                  # 서비스 생성·Scope 주입·테마·라우트
├── core/
│   ├── app_routes.dart       # 화면 경로 상수
│   ├── layout/               # 반응형 기준
│   ├── theme/                # 공통 색상·텍스트 스타일·테마
│   └── widgets/              # 내비게이션 셸·공통 UI
└── features/
    ├── auth/                 # 로그인·세션·토큰 저장
    ├── calendar/             # 캘린더 UI·컨트롤러·서버/Google API
    ├── course/               # 강의 관리
    ├── home/                 # 홈 대시보드
    ├── notice_feed/          # 공지 피드·수집처 설정
    ├── notification/         # 내부 알림·읽음·저장
    │   ├── push/             # FCM·플랫폼별 수신함
    │   └── realtime/         # WebSocket·HTTP 동기화
    ├── settings/             # 앱 설정·수집 설정
    └── splash/               # 시작 화면
test/                         # 소스 구조에 대응하는 서비스·위젯 테스트
tool/
├── verify.sh                 # 공통 검증 진입점
├── configure_push.py         # 웹 Firebase 설정 생성
└── push_server/              # 로컬 푸시 테스트 서버·발송 도구·테스트
docs/                         # 설계·연동·검증 문서와 작업 기록
assets/                       # NotoSansKR 폰트·아이콘
config/                       # Firebase 설정 예시와 로컬 설정
android/                      # Android 설정
ios/                          # iOS 설정
web/                          # 웹 진입점·푸시 서비스 워커
```

`main.dart`에서 `InbbiApp`을 실행하고, `app.dart`에서 인증·캘린더·알림 서비스를 구성합니다. 상태는 주로 `ChangeNotifier`와 `InheritedWidget`/`InheritedNotifier` 기반 `Scope`로 전달합니다. `MainTabShell`은 `IndexedStack`으로 메인 화면을 전환합니다. 캘린더 API와 알림 로직은 UI와 분리되어 있습니다.

## 검증과 빌드

의존성을 준비한 뒤 공통 검증을 실행합니다.

```sh
flutter pub get
bash tool/verify.sh
```

기본 검증은 `lib/`, `test/`의 서식 확인, `flutter analyze`, 전체 Flutter 테스트 순으로 실행하며 첫 실패에서 종료합니다. 서식을 자동 수정하지 않습니다.

기능별 테스트를 선택할 수도 있습니다. 각 명령은 전체 Dart 서식·정적 분석을 함께 확인합니다.

```sh
bash tool/verify.sh calendar
bash tool/verify.sh notices
bash tool/verify.sh notifications
bash tool/verify.sh auth
bash tool/verify.sh settings
```

푸시 서버 테스트는 별도 Python 환경에서 실행하며 실제 FCM 발송을 하지 않습니다.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tool/push_server/requirements.txt
PATH="$PWD/.venv/bin:$PATH" bash tool/verify.sh push-server
```

플랫폼별 릴리스 빌드 명령은 다음과 같습니다. 외부 연동을 포함하려면 실행할 때와 동일한 `--dart-define` 또는 `--dart-define-from-file` 옵션을 전달합니다. 웹 푸시 빌드 전에는 같은 Firebase 설정으로 설정 생성기도 실행합니다.

```sh
flutter build web
flutter build apk
flutter build ios
```

자동 테스트와 빌드 성공만으로 실제 계정 연동이나 기기 전달이 검증되지는 않습니다. Google 연결·해제, 기기별 권한, 앱 실행·백그라운드·종료 상태의 푸시 수신은 별도로 확인하고 기록합니다.

## 개발 지침과 관련 문서

- [저장소 기여 지침](AGENTS.md): 작업 범위, 코드 스타일, UI 보존, 검증 기준
- [하네스 엔지니어링](docs/harness_engineering.md): 작업 절차와 기능별 코드·검증 지도
- [작업 템플릿](docs/tasks/TEMPLATE.md): 여러 단계 작업의 범위·완료 조건·결과 기록
- [캘린더 개발](docs/calendar_development.md): 샘플 일정, OAuth 설정, 일정 API 계약
- [캘린더 연동 계획](docs/calendar_integration_plan.md)
- [RHEL 테스트 서버 계획](docs/rhel_calendar_test_server_plan.md)
- [앱 내부 알림](docs/in_app_notifications.md): 목록·읽음·저장 정책
- [푸시 알림](docs/push_notifications.md): Firebase·APNs 설정과 테스트 발송
- [알림 프로토콜](docs/notification_protocol.md): 실시간 수신·목록 복구·기기 등록 계약

문서의 과거 검증 기록과 계획은 현재 완료 상태와 구분해 확인합니다. 기능의 현재 동작은 코드와 해당 테스트를 함께 참고합니다.
