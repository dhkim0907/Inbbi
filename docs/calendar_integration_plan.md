# 앱 서버·Google Calendar 병행 사용 계획

> 2026-09 확장: 이 문서의 “1차 읽기 전용” 내용은 초기 계획이다. 현재 앱 서비스에는 Google 기본 캘린더의 일정 **생성·수정** 호출이 추가되었으며 권한은 `calendar.events`다. 생성·수정 UI는 아직 없고, 서버 프로젝트의 쓰기 API는 별도 구현이 필요하다. 최신 계약은 [캘린더 클라이언트 연결 방법](calendar_development.md)과 [RHEL 테스트 서버 계획](rhel_calendar_test_server_plan.md)을 따른다.

## 용어와 목표

이 문서에서 **기본 일정**은 앱 서버 API에서 받아오는 일정이다. 이전 문서의 “로컬 일정”은 기기 내부 저장 일정을 뜻하지 않는다. 기기 저장소를 기본 일정의 원본으로 사용하지 않는다.

- Google 계정을 연결하지 않아도 앱 서버의 일정 조회와, 서버가 허용하는 일정 생성·수정·삭제가 작동한다.
- Google 계정을 연결하면 기본 일정에 Google 기본 캘린더(`primary`)의 일정을 더해 한 화면에서 보여 준다.
- 1차 Google 연동은 **읽기 전용**이다. 기본 일정을 Google에 자동 업로드하거나 Google 일정을 앱 서버에 복제하지 않는다. Google 쓰기와 양방향 동기화는 별도 결정 사항이다.
- 서버와 Google 중 한쪽 조회가 실패해도 성공한 쪽의 일정은 표시한다. 양쪽 모두 실패한 경우에는 원인을 구분해 재시도 방법을 보여 준다.
- 대상 플랫폼은 현재 앱의 Android, iOS, 웹이다.

## 현재 코드와 필요한 계약

| 위치 | 현재 상태 | 변경 방향 |
| --- | --- | --- |
| `lib/features/calendar/calendar_page.dart` | 2026년 6월 고정 월과 목업 일정 | 실제 조회 결과, 날짜 범위, 상태별 화면, 기본 일정 편집 동작 사용 |
| `lib/features/home/home_dashboard_page.dart` | 캘린더 탭과 별도의 목업 미니 캘린더 | 캘린더 탭과 같은 서버 일정 서비스 사용 |
| `lib/features/settings/settings_page.dart` | Google 연결 상태를 화면 내부 불리언으로 변경 | 실제 계정 연결·해제·권한·동기화 상태 표시 |
| `lib/core/widgets/month_calendar_grid.dart` | 날짜와 일정 표시 점을 받는 공통 위젯 | 유지하고 통합 일정의 날짜 집합을 전달 |
| 앱 서버 | 이 저장소에는 일정 API 계약·구현이 없음 | 아래 API 계약을 백엔드와 확정한 뒤 연결 |

### 앱 서버 일정 API 초안

앱 인증으로 사용자별 일정을 분리한다. 모든 날짜 범위는 시간대가 포함된 ISO 8601 시각으로 전달하고, 종료 경계는 포함하지 않는다.

| 동작 | API 초안 | 필수 사항 |
| --- | --- | --- |
| 범위 조회 | `GET /api/v1/calendar/events?timeMin=...&timeMax=...&cursor=...` | 페이지네이션, 월 경계에 걸친 일정 포함, 삭제된 일정의 재조회 반영 |
| 생성 | `POST /api/v1/calendar/events` | 검증, 안정적인 ID, 중복 요청 방지 키 |
| 수정 | `PATCH /api/v1/calendar/events/{id}` | 버전 또는 ETag로 동시 수정 충돌 식별 |
| 삭제 | `DELETE /api/v1/calendar/events/{id}` | 소유권 확인, 관련 예약 알림 취소 |

응답 모델은 최소한 `id`, `title`, `category`, `start`, `end`, `allDay`, `timeZone`, `updatedAt`, `version`을 포함한다. 서버에 이미 일정 API가 있다면 경로를 새로 만들기 전에 기존 계약을 확인하고 어댑터를 작성한다. 서버의 생성·수정·삭제 지원 여부가 확정될 때까지 UI에서 가능한 작업을 실제 지원 범위에 맞춰 노출한다.

## 서비스 구조

```text
CalendarPage / HomeDashboardPage / SettingsPage
                    ↓
             CalendarController
                    ↓
            CalendarRepository
             ↙            ↘
 AppCalendarService   GoogleCalendarService
       ↓                      ↓
 앱 서버 일정 API       GoogleAuthService + Calendar API
```

1. `CalendarEvent`는 `source(appServer|google)`와 출처별 원본 ID를 보존한다. Google 항목의 키는 `calendarId + eventId`로 만들고, 같은 제목·시간만으로 두 출처의 항목을 합치지 않는다.
2. `AppCalendarService`가 앱 서버 조회·생성·수정·삭제, 인증 오류, 페이지네이션, 재시도를 담당한다. 위젯은 HTTP를 직접 호출하지 않는다.
3. `GoogleAuthService`가 계정 연결·권한 요청·재인증·연결 해제를 담당한다. 인증 토큰은 일정 데이터나 로그에 기록하지 않는다.
4. `GoogleCalendarService`가 Google 일정 조회와 응답 변환을 담당한다. 1차에는 Google 일정에 편집 동작을 표시하지 않는다.
5. `CalendarRepository`가 두 출처의 조회를 병행하고 부분 성공을 허용한다. 서버 일정만 있을 때, Google 일정만 있을 때, 둘 다 있을 때를 구분한다.
6. 화면 상태는 출처별 `loading`, `ready`, `empty`, `authRequired`, `error`로 관리한다. Google 인증 실패가 서버 일정 사용을 막지 않으며 서버 인증 실패도 별도로 안내한다.

## 조회·연결 흐름

1. 앱 시작 시 현재 월의 앱 서버 일정을 조회한다. Google 연결 여부와 관계없이 이 조회를 수행한다. 서버 연결이 없을 때 “로컬 일정”이라고 표시하지 않는다.
2. 설정에서 Google 계정을 연결하면 일정 조회 권한 `calendar.events.readonly`를 요청한다. 권한을 거부하거나 인증이 만료되면 서버 일정만 계속 표시한다. [Google 권한 목록](https://developers.google.com/workspace/calendar/api/auth)
3. 연결 성공 시 Google 기본 캘린더의 현재 월을 조회하고 서버 일정과 합쳐 표시한다. 월 이동·사용자 새로고침·앱 재개 시 필요한 월을 다시 조회한다. 반복 일정은 `singleEvents=true`로 인스턴스를 표시하고 `nextPageToken`을 끝까지 처리한다. [Events: list](https://developers.google.com/workspace/calendar/api/v3/reference/events/list)
4. Google 연결 해제 시 Google 인증 정보와 화면의 Google 일정을 제거한다. 서버 일정은 그대로 다시 조회·표시한다. 앱 서버 로그아웃은 해당 서버의 기존 인증 정책에 따른다.
5. 1차에는 월 범위 재조회를 사용한다. Google `syncToken`은 `timeMin`·`timeMax`와 함께 사용할 수 없어 월별 범위 조회에 섞지 않는다. 전체 증분 동기화가 필요해지면 별도 설계에서 삭제 항목과 만료 토큰의 HTTP 410을 처리한다. [Events: list](https://developers.google.com/workspace/calendar/api/v3/reference/events/list), [증분 동기화 가이드](https://developers.google.com/workspace/calendar/api/guides/sync)

## 플랫폼과 날짜 처리

- `google_sign_in`의 Android·iOS·웹 설정과 실제 버전의 인증·권한 API를 확인하고 플랫폼별 OAuth 클라이언트 ID를 준비한다. 웹에서는 액세스 토큰 만료 후 사용자 동작을 통해 다시 권한을 요청해야 할 수 있다. 테스트 클라이언트와 테스트 계정만 사용한다. [Flutter google_sign_in](https://pub.dev/packages/google_sign_in), [Google 웹 토큰 모델](https://developers.google.com/identity/oauth2/web/guides/use-token-model)
- 두 출처 모두 시간 지정 일정은 원래 오프셋·시간대를 파싱하고 앱의 표시 시간대로 변환한다. 종일 일정은 날짜 값으로 보존한다. Google의 종일 일정 종료 날짜는 포함되지 않으므로 마지막 표시 날짜는 그 전날이다. [Google 이벤트 리소스](https://developers.google.com/workspace/calendar/api/v3/reference/events)
- 월 경계, 윤년, 서머타임, 여러 날 종일 일정, 반복 일정의 예외·취소 인스턴스를 검증한다. 앱 서버 응답에도 동일한 날짜 규칙을 적용하도록 계약을 맞춘다.
- 기기 캐시를 도입한다면 화면 속도나 일시적 오프라인 표시를 위한 보조 수단으로만 사용한다. 캐시의 만료·계정 분리·삭제 정책을 별도로 정하고, 이를 서버 일정의 원본으로 취급하지 않는다.

## 구현 순서와 완료 조건

- [ ] **1. 서버 계약 확정:** 기존 일정 API 유무, 사용자 인증, 범위 조회·페이지네이션, CRUD 지원, 날짜·종일 일정 형식을 확인한다.
- [ ] **2. 서버 일정 연결:** 서비스와 모델을 만들고 캘린더 화면의 고정 목업을 교체한다. Google 미연결 상태에서 서버 일정 조회와 지원되는 편집 동작을 검증한다.
- [ ] **3. Google 인증:** Android·iOS·웹에서 연결·권한 거부·재인증·해제를 구현하고 테스트 계정으로 확인한다.
- [ ] **4. 통합 조회:** Google 기본 캘린더 월 범위 조회, 페이지네이션, 출처 표시, 부분 실패·빈 상태·재시도를 구현한다.
- [ ] **5. 화면 공유:** 홈 미니 캘린더와 캘린더 탭이 같은 서버 일정 데이터를 쓰게 한다. 모바일 너비 390·839와 데스크톱 840·1280에서 레이아웃을 확인한다.
- [ ] **6. 알림 연결:** 서버 일정의 생성·변경·삭제에 따른 알림 갱신 주체를 서버/앱 사이에서 확정한다. Google 일정에 앱 알림을 별도로 생성할지는 Google 기본 알림과의 중복 정책을 정한 뒤 구현한다.
- [ ] **7. 검증:** 서버·Google API 대역 테스트로 인증, 페이지 처리, 중복 ID, 부분 실패, 날짜 표시, 연결 해제를 확인한다. 실제 테스트 계정으로 Android·iOS·웹 연결·조회·해제 결과를 기록하고 `flutter analyze`와 관련 테스트를 실행한다.

## 후속 결정 사항

현재 구현 현황과 연결 설정은 [캘린더 클라이언트 연결 방법](calendar_development.md)에 기록한다. 앱 서버와 실제 로그인 API가 아직 없으므로 서버 계약 확정과 실계정 검증 항목은 미완료로 유지한다.

- Google 일정 조회만 유지할지, 앱 서버 일정을 Google에 게시할지, Google 일정 자체를 편집할지 결정한다. 쓰기를 선택하면 권한, 대상 캘린더, 충돌 해결, 삭제 전파, 중복 생성 방지 정책이 필요하다.
- Google 기본 캘린더 외의 캘린더를 선택할지, 앱 서버 일정과 Google 일정이 동일한 현실 이벤트를 가리킬 때 사용자에게 어떻게 표시할지 결정한다.
- 기기 캐시가 필요한지와 서버 장애·오프라인 상태에서 보여 줄 마지막 조회 결과의 보존 기간을 정한다.
