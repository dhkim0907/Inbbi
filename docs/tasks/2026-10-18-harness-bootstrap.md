# 작업: 하네스 개발 기반 구성

상태: 기반 구성 완료, 기존 검증 실패는 후속 작업

## 목표와 범위

- AI와의 개발에 사용할 지침·코드 탐색·검증·결과 기록을 저장소에 마련한다.
- 변경 범위: `AGENTS.md`, `README.md`, 하네스 가이드, 작업 템플릿, 검증 스크립트와 이 기록.
- 기존 작업 중인 변경과 앱 UI·Dart 코드·기능 테스트는 보존한다.

## 완료 조건

- [x] 작업 범위와 완료 조건을 기록하는 템플릿 제공
- [x] 기능별 코드·테스트 탐색 지도와 개발 절차 문서화
- [x] 서식을 변경하지 않는 공통 검증 명령 제공 및 기존 서식 실패 감지
- [x] 정적 분석과 전체 Flutter 테스트 실행 결과 기록
- [ ] 저장소 전체 서식·테스트 통과: 기존 실패 해결 필요

## 검증 기록

검증일: 2026-10-18. 로컬 macOS, Flutter 3.47.5 stable / Dart 3.13.4. Flutter 명령은 SDK 캐시 접근을 허용한 환경에서 실행했다. 앱 코드와 기존 테스트를 수정하지 않은 현재 작업 트리 기준이다.

| 명령 | 실제 결과 |
|---|---|
| `bash -n tool/verify.sh` | 통과 |
| `bash tool/verify.sh --help` | 사용법 출력, 정상 종료 |
| `bash tool/verify.sh` | 종료 코드 1. 기존 `lib/features/course/course_management_page.dart`, `lib/features/notice_feed/notice_feed_page.dart` 서식 불일치 감지. `--output=none`이므로 파일 수정 없음. 이후 단계는 실행하지 않음 |
| `flutter analyze --no-pub` | 통과, No issues found |
| `flutter test --no-pub` | 종료 코드 1. 134개 통과, 21개 실패 |
| `git diff --check` | 통과 |

실패 예시:

- `calendar_service_test.dart:696`: 일정 저장 시나리오의 `ensureVisible`에서 `Bad state: No element`.
- `calendar_service_test.dart:946`: 모바일 화면의 `전체` 문구 부재 기대와 실제 화면 불일치.
- `calendar_service_test.dart:936`: 데스크톱 화면의 너비 기대값과 실제 값 불일치.
- `calendar_service_test.dart:1113`: 설정 화면에서 `일정 권한 허용` 문구를 찾지 못함.
- `push_service_test.dart:225`: 외부 알림 설정 위젯 테스트에서 예외 발생.

실패 원인과 올바른 기대 동작은 개별 작업에서 확인해야 한다. 통과시키기 위해 기대값만 바꾸거나 요청되지 않은 UI를 변경하지 않는다.

## 남은 사항

- 기존 서식 2건과 테스트 실패 21건을 별도 작업에서 검토·해결해야 공통 검증 전체가 통과한다.
- Python 푸시 서버 테스트는 이번에 실행하지 않았다. 현재 `python3` 환경에 `firebase_admin`이 설치되어 있지 않다. 별도 가상환경 구성 절차는 하네스 가이드에 기록했다.
- 실제 계정 연결, 실기기 알림 전달, 모바일·데스크톱 수동 화면 확인과 플랫폼 빌드는 실행하지 않았다. 이번 변경에는 앱 UI나 플랫폼 코드 수정이 없다.
- CI 연결은 이번 범위에 포함하지 않았다. 자동화할 때도 같은 `bash tool/verify.sh` 진입점을 사용한다.
