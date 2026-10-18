# Inbbi 하네스 엔지니어링

하네스는 AI가 작업할 때 필요한 지침, 코드 탐색 경로, 검증 명령, 결과 기록을 저장소 안에 함께 관리하는 개발 환경이다. 사람은 목표와 허용 범위, 완료 조건을 정하고 AI는 구현과 검증을 반복한다. 실패 원인이 반복되면 관련 지침이나 검증 수단을 개선한다.

## 작업 순서

1. `AGENTS.md`와 관련 기능 문서를 읽고 `git status --short`로 기존 변경을 확인한다.
2. 아래 작업 템플릿으로 목표, 변경 허용 범위, 보존할 동작, 완료 조건을 기록한다. 간단한 작업은 대화에 기록하고, 여러 단계의 작업은 `docs/tasks/`에 파일로 남긴다.
3. 관련 서비스·컨트롤러와 기존 테스트를 읽는다. 오류 수정은 재현 가능한 입력과 기대 동작을 먼저 정한다.
4. 필요한 범위만 구현한다. 외부 API·인증·저장소는 기존 인터페이스와 테스트 대역을 재사용한다. UI 변경은 명시적으로 요청된 범위에 한한다.
5. 수정한 Dart 파일만 `dart format <파일 경로...>`으로 정리한 다음 아래 검증을 실행한다. 실패하면 원인을 확인하고 작업 범위의 문제만 수정한다.
6. 최종 차이를 검토하고 변경 내용, 실행한 검증과 결과, 실행하지 못한 항목을 보고한다. 완료 조건을 실제 확인한 항목만 완료로 표시한다.

기존 변경 때문에 검증이 실패하면 파일과 실패 내용을 기록한다. 전체 서식 적용이나 무관한 코드 수정으로 기존 변경을 덮어쓰지 않는다. 사용자가 요청하지 않은 커밋·푸시는 하지 않는다.

## 코드와 검증 탐색 지도

| 작업 | 코드 시작점 | 관련 검증 / 문서 |
|---|---|---|
| 캘린더 화면·일정 조작 | `lib/features/calendar/calendar_page.dart`, `calendar_controller.dart`, `calendar_event_writer.dart` | `test/features/calendar/`, `test/core/widgets/calendar_week_event_bars_test.dart`, [캘린더 개발](calendar_development.md) |
| Google 계정·일정 API | `lib/features/calendar/google_calendar_auth.dart`, `google_calendar_api.dart`, `google_calendar_server_link.dart` | `test/features/calendar/calendar_service_test.dart`, `google_calendar_server_link_test.dart`, [연동 계획](calendar_integration_plan.md) |
| 앱 내부 알림·읽음 상태 | `lib/features/notification/notification_service.dart`, `notification_page.dart` | `test/features/notification/`, [내부 알림](in_app_notifications.md), [프로토콜](notification_protocol.md) |
| 푸시·실시간 수신 | `lib/features/notification/push/`, `lib/features/notification/realtime/`, `tool/push_server/` | `test/features/notification/`, `tool/push_server/test_server.py`, [푸시 알림](push_notifications.md) |
| 앱 인증 | `lib/features/auth/auth_session_service.dart`, `test_auth_api.dart` | `test/features/auth/` |
| 설정·저장 정책 | `lib/features/settings/` | `test/features/settings/` |
| 공통 레이아웃·탐색 | `lib/core/widgets/`, `lib/core/layout/app_breakpoints.dart`, `lib/core/app_routes.dart` | `test/core/widgets/`, `test/widget_test.dart` 및 각 기능 위젯 테스트 |

## 반복 가능한 검증

프로젝트 루트에서 의존성을 준비한 뒤 공통 진입점을 실행한다. SDK 조건은 `pubspec.yaml`, 잠금 의존성은 `pubspec.lock`을 기준으로 한다.

```sh
flutter pub get
bash tool/verify.sh
```

`verify.sh`는 첫 실패에서 종료하며 서식을 자동 수정하지 않는다. 전체 `lib/`, `test/`의 서식과 정적 분석을 확인하고 기본값으로 전체 Flutter 테스트를 실행한다. 내부 명령에는 `--no-pub`를 사용하므로 의존성을 변경했다면 먼저 `flutter pub get`을 실행한다.

빠른 피드백을 위해 기능 테스트를 선택할 수 있다. 기능 검증만으로 전체 회귀 검증을 대체하지 않는다.

```sh
bash tool/verify.sh calendar
bash tool/verify.sh notifications
bash tool/verify.sh auth
bash tool/verify.sh settings
```

푸시 서버를 수정하면 별도 Python 환경에서 추가 검증한다. 아래 테스트는 실제 FCM 전송을 하지 않는다.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tool/push_server/requirements.txt
PATH="$PWD/.venv/bin:$PATH" bash tool/verify.sh push-server
```

웹 플랫폼의 import·컴파일이나 배포 설정을 수정하면 `flutter build web`도 실행한다. Android·iOS 설정을 수정하면 해당 SDK가 설치된 환경에서 빌드와 실기기 검증을 추가한다. 실행하지 못한 플랫폼을 통과로 기록하지 않는다.

## 완료 조건의 증거

- 로직: 정상 흐름과 변경한 경계·실패 조건을 기존 테스트 또는 필요한 회귀 테스트로 확인한다. 구현을 그대로 복제하는 테스트는 추가하지 않는다.
- 요청된 UI 변경: 모바일과 데스크톱을 확인한다. 반응형 분기와 관련되면 839·840 논리 픽셀을 포함한다. 기존 캘린더 테스트에는 390·839·840·1280 너비 시나리오가 있다. 위젯 테스트와 실제 화면 확인 결과를 구분한다.
- 캘린더 연동: 모의 API 테스트와 테스트 계정의 실제 연결·조회·해제 결과를 구분한다. 시간대, 종일 일정의 배타적 종료일, 권한 거부·만료·네트워크 실패를 확인한다.
- 알림: 플랫폼과 로컬 예약/서버 푸시 방식을 구현 전에 명시한다. 선택한 SDK 공식 문서로 제약을 확인하고 실제 전달은 별도로 기록한다. 서버 접수만으로 기기 전달 완료를 표시하지 않는다.
- 비밀 정보: 테스트 대역과 테스트 데이터를 사용한다. 토큰·키를 코드, 작업 문서, 검증 로그에 넣지 않는다.

새 검증을 추가할 때는 잡으려는 실패를 설명할 수 있어야 한다. 실제 계정·기기 접근이 필요한 완료 조건은 자동 테스트가 통과해도 미검증 상태로 남긴다.

## 작업 요청 예시

```text
AGENTS.md와 docs/harness_engineering.md를 따른다.
목표: 캘린더에서 이전 월 요청이 늦게 끝나도 현재 월 일정을 덮어쓰지 않게 한다.
범위: CalendarController와 관련 서비스 테스트. UI는 유지한다.
완료 조건: 응답 순서를 바꾼 테스트에서 현재 월 일정이 유지된다.
검증: bash tool/verify.sh calendar 후 bash tool/verify.sh.
기존 변경을 보존하고 결과와 미검증 항목을 한국어로 보고한다.
```

이 예시는 작업 형식이며 현재 버그가 확인되었다는 의미는 아니다. 여러 단계의 작업에는 [작업 템플릿](tasks/TEMPLATE.md)을 복사해 사용한다.

## Figma를 기준으로 UI 개발하기

현재 적용 작업은 [‘인삐 UI’ 캘린더·공지 구현 계획](tasks/2026-10-18-figma-inbbi-ui.md)에서 관리한다.

1. 파일 URL과 페이지·프레임 ID, 조회일, 대상 화면·상태를 작업 문서에 기록한다. 파일 이름만으로 디자인을 추정하지 않는다.
2. 디자인 컨텍스트와 스크린샷을 읽고 기존 위젯·테마·에셋에 대응시킨다. 구현 허용 범위를 프레임 단위로 적는다.
3. 화면이나 상태 하나씩 구현하고 기존 상호작용을 유지한다. 필요한 원본 아이콘·이미지는 로컬 에셋으로 등록한다.
4. 관련 동작 테스트와 모바일·데스크톱 렌더링 비교를 수행한다. 프레임 → 코드 → 테스트·스크린샷의 연결과 실제 결과를 문서에 남긴다.
5. 전체 검증의 기존 실패와 새 실패를 구분한다. 읽지 못한 디자인과 확인하지 못한 화면은 미완료로 남긴다.

Figma 원본 수정과 앱 구현은 별도 작업이다. 디자인을 읽고 구현하는 요청만으로 원본 파일을 수정하지 않는다.
