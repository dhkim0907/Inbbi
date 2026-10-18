# 캘린더 클라이언트 연결 방법

## 개발용 샘플 일정

디버그 실행에서는 강의·과제·일정·할일 각각의 미완료·완료 항목과 종일·여러 날 일정을 총 10개 표시한다. 제목에 `[샘플]`을 붙이며 서버나 Google에 저장하지 않는다. 현재 월은 오늘 날짜에, 다른 월은 같은 일자(해당 월에 없으면 마지막 날)에 샘플을 배치한다. 월 이동과 새로고침 후에도 확인할 수 있다.

샘플을 숨기려면 `flutter run --dart-define=CALENDAR_SAMPLE_DATA=false`로 실행한다. 릴리스·프로파일 실행에는 샘플이 포함되지 않는다. 코드 변경 후 실행 중인 앱에는 Hot Restart를 적용한다.

현재 앱은 앱 서버 일정 API와 Google Calendar API를 각각 조회해 화면에서 합친다. 앱 서버는 아직 이 저장소에 없고 로그인 화면도 목업이다. 따라서 서버 주소·실제 로그인 토큰·Google OAuth 클라이언트 설정이 없으면 캘린더에는 임의의 일정이 표시되지 않는다.

## 앱 서버 계약

### RHEL 테스트 서버에 Google 연결하기

앱 로그인 토큰과 API 서버가 준비되면 설정 탭의 `Google Calendar 연동`에서 처음 연결을 시작한다. 앱은 Google의 **일회용 서버 인증 코드**를 API 서버로 보내고, 서버는 인증된 앱 사용자 ID를 기준으로 코드를 교환해 갱신 토큰을 암호화 저장한다. 앱에는 갱신 토큰을 저장하지 않는다. 다음 로그인에서는 서버 연결 상태를 확인해 연결 버튼을 숨기고 서버 일정을 조회한다. 설정에서 연결 상태를 확인하고 연결을 해제한다. 현재 로그인 화면은 목업이라 앱 로그인 토큰을 발급하지 않는다. 실제 로그인 연동 후 `CalendarController.setAppToken`에 받은 앱 토큰을 전달해야 한다. 그 전에는 기존 Google 직접 조회로 테스트할 수 있다.

- `POST /api/v1/calendar/google/connection` — 앱 인증 `Authorization: Bearer <앱 토큰>`과 JSON `{"authorizationCode":"<일회용 코드>"}`. 성공 시 2xx. 코드는 재사용하지 않으며 로그에 기록하지 않는다.
- `GET /api/v1/calendar/google/connection` — 동일한 앱 인증. JSON `{"connected":true|false}`. 앱 로그인 후 연결 상태를 복원한다.
- `DELETE /api/v1/calendar/google/connection` — 동일한 앱 인증. 서버의 해당 사용자 Google 연결을 해제하고 저장된 갱신 토큰을 삭제한다. 성공 시 2xx.
- `GET /api/v1/calendar/events?...` — 기존 일정 계약. 서버가 앱 사용자별 Google 일정을 반환하려면 이 엔드포인트에서 연결된 계정의 갱신 토큰을 사용한다. 두 계정 데이터가 섞이지 않도록 앱 토큰에서 사용자 ID를 검증한다.
- `POST /api/v1/calendar/events` — 현재 앱 사용자 Google **기본 캘린더**에 일정 생성. JSON 본문은 `title`, `category: "Google"`, `calendarId: "primary"`, `allDay`, `start`, `end`. 성공 시 아래 일정 객체를 반환한다.
- `PATCH /api/v1/calendar/events/{id}` — 해당 사용자 기본 캘린더의 기존 Google 일정 수정. 본문·응답 형식은 생성과 동일하다. 서버는 소유자와 Google 출처를 검사하고, 타 사용자 또는 다른 출처 일정 수정을 거부한다.

쓰기 요청 예시: `{"title":"시험","category":"Google","calendarId":"primary","allDay":false,"start":"2026-09-27T09:00:00.000Z","end":"2026-09-27T10:00:00.000Z"}`. 응답은 조회의 `items` 원소와 같은 일정 객체 한 개다. 종일 일정은 `allDay:true`와 `YYYY-MM-DD` 시작·배타적 종료 날짜를 사용한다. 401/403은 앱 인증 실패, 404는 수정 대상 없음으로 처리한다. 서버는 수정 대상이 현재 사용자에게 속하는지 검사한다.

앱 코드는 서버 인증 코드·Google 액세스 토큰·갱신 토큰을 로컬 저장소에 직접 기록하지 않는다. Google SDK가 자체적으로 로그인 상태를 관리할 수는 있다. 앱 로그인 토큰은 현재 `CalendarSession`의 메모리에만 보관한다. 앱을 다시 실행하면 앱 로그인으로 새 세션을 얻어야 하며, 서버는 저장된 갱신 토큰으로 Google 일정을 계속 조회할 수 있다. 앱이 새 로그인 토큰을 받으면 연결 상태를 다시 조회한다. 연결 상태가 확인된 동안 서버 Google 일정과 앱의 직접 조회 결과를 중복 표시하지 않는다.

테스트 서버 공개 주소는 `CALENDAR_API_URL=https://api.example.com/`처럼 **포트 없는 HTTPS 도메인**으로 전달한다. Cloudflare Tunnel의 내부 대상 포트는 서버 실행 환경 변수와 터널 설정에서 함께 바꿀 수 있다. Google 웹 OAuth는 웹 앱의 **접속 원본(도메인과 포트)**을 승인 목록에 등록해야 하므로, 웹 앱도 포트 고정 없이 실행하려면 테스트용 고정 HTTPS 도메인으로 제공하는 편이 적합하다. `localhost`에서 Flutter 웹 앱을 매번 다른 포트로 실행하면 각 포트를 OAuth 승인 원본에 추가해야 한다.

클라이언트는 `CALENDAR_API_URL`을 기본 URL로 사용한다. 경로 `/`로 끝나는 HTTPS URL을 지정한다. 조회 요청은 다음과 같다.

```http
GET /api/v1/calendar/events?timeMin=<UTC ISO 8601>&timeMax=<UTC ISO 8601>&cursor=<optional>
Authorization: Bearer <app account access token>
```

```json
{
  "items": [
    {
      "id": "event-001",
      "title": "시험",
      "category": "과제",
      "allDay": false,
      "start": "2026-09-27T09:00:00+09:00",
      "end": "2026-09-27T10:00:00+09:00"
    }
  ],
  "nextCursor": null
}
```

`end`는 포함되지 않는다. 종일 일정은 `allDay: true`와 `YYYY-MM-DD` 형식의 `start`·`end`를 사용한다. 서버는 월 경계와 겹치는 일정도 반환한다. 페이지가 더 있으면 `nextCursor`를 보내고, 마지막 페이지에서는 `null`을 보낸다. 서버의 401/403은 다시 로그인해야 하는 상태로 표시된다.

실제 로그인 연동 후 발급받은 토큰을 `CalendarController.ㄴsetAppToken`으로 전달한다. 현재 로그인 화면은 목업이므로 앱 서버 일정 조회에는 아직 인증 토큰이 전달되지 않는다. 이 값은 코드·설정 파일·로그에 저장하지 않는다.

## Google OAuth 설정

Google Cloud 테스트 프로젝트에서 Calendar API를 사용 설정하고 Android, iOS, 웹용 OAuth 클라이언트를 등록한다. 앱은 조회·생성·수정을 위해 `calendar.events` 권한을 요청한다. 기존 `calendar.events.readonly` 동의만 받은 계정은 더 넓은 권한에 다시 동의해야 한다. 웹 클라이언트 ID는 `GOOGLE_WEB_CLIENT_ID`, iOS 클라이언트 ID는 `GOOGLE_IOS_CLIENT_ID`로 전달한다. Android에서는 등록된 패키지명·서명 SHA와 웹 클라이언트 ID가 맞아야 한다. iOS는 `Info.plist`의 URL scheme에 해당 클라이언트의 reversed client ID도 등록해야 한다. 이 값들은 테스트 프로젝트에서 얻어야 하므로 저장소에 실제 값을 넣지 않는다. [Flutter google_sign_in](https://pub.dev/packages/google_sign_in), [Google Calendar 권한](https://developers.google.com/workspace/calendar/api/auth)

```sh
flutter run -d chrome \
  --dart-define=CALENDAR_API_URL=https://your-test-server.example/ \
  --dart-define=GOOGLE_WEB_CLIENT_ID=your-web-client-id
```

연결 시작 버튼은 설정 탭의 `Google Calendar 연동`에 있다. Android·iOS에서는 Google 계정 선택 직후 서버 인증 코드를 요청한다. 웹에서는 `Google Calendar 연결` 버튼으로 계정 선택과 Calendar 권한 동의를 함께 요청한다. 앱 서버 로그인이 연결된 경우에는 서버 인증 코드를 추가로 요청한다. 브라우저가 추가 사용자 동작을 요구하거나 코드 발급에 실패하면 설정 탭의 `Google 연결 계속` 버튼으로 재시도한다. 이 제한 때문에 웹에서 모든 계정에 대해 한 번의 클릭만으로 완료됨을 보장할 수는 없다. 서버가 연결을 확인하면 앱은 서버 일정만 표시한다. 연결 후에는 설정의 `Google Calendar 연동` 행에서 연결을 해제한다.

### 로그인했는데 일정이 보이지 않을 때

웹의 첫 연결은 계정 선택과 `calendar.events` 동의를 한 동작에서 요청한다. 권한이 만료되었거나 이전에 거부한 경우에는 설정 탭에서 `일정 권한 허용`을 눌러 다시 동의한 뒤 현재 월의 날짜를 확인한다. 앱은 연결한 계정의 **기본 캘린더(`primary`)**와 현재 표시 중인 월만 조회하며, 선택한 날짜의 일정만 오른쪽/아래 목록에 보여 준다. 앱 서버 주소가 설정되지 않은 상태는 캘린더 화면에서 오류로 표시하지 않으며 Google 조회를 막지 않는다.

생성·수정은 아직 UI 없이 `CalendarController.createGoogleEvent(draft)`와 `updateGoogleEvent(eventId, draft)`로 제공한다. `CalendarEventDraft`는 제목, 시작·종료, 종일 여부를 받고 종료 시각/날짜는 포함하지 않는다. 서버 연결 중에는 앱 Bearer 토큰으로 `POST`·`PATCH`를 사용하고, 서버 미연결 테스트 모드에서는 Google API의 `events.insert`·`events.patch`를 직접 호출한다. 수정 시 화면에서 받은 `server:<id>` 또는 `google:primary:<id>`를 사용한다. 성공 후 현재 월을 다시 조회한다. 참석자·반복 일정·다른 캘린더 수정은 아직 지원하지 않는다. 상세보기의 수정·삭제 구현과 서버 요구 계약은 아래를 참조한다. [Google 생성 API](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert), [Google 수정 API](https://developers.google.com/workspace/calendar/api/v3/reference/events/patch)

권한을 허용했는데도 `Google 일정 접근이 거부됐어요(403)`가 표시되면 Google Cloud에서 Calendar API 사용 설정, OAuth 동의 화면의 범위, 테스트 사용자를 확인한다. API 응답이 0개면 캘린더 탭에 `이 달의 Google 기본 캘린더에 일정이 없어요`가 표시된다. 응답은 있는데 날짜 형식을 처리하지 못하면 오류를 표시한다. 다른 캘린더의 일정이나 Google Tasks의 할 일은 현재 연동 범위에 포함되지 않는다.

## 현재 확인 범위

서비스 대역 테스트로 서버·Google 페이지 조회, 인증 오류, 종일 일정 종료일, 출처 병합과 부분 실패를 확인한다. 캘린더 화면은 너비 390·839·840·1280에서 검사한다. 실제 서버와 Google 테스트 계정이 준비되기 전에는 실계정 연결·전달 테스트와 앱 서버의 생성·수정·삭제 검증을 완료할 수 없다.


## 일정 추가 입력창

캘린더 오른쪽 아래 `+` 버튼은 선택한 날짜를 기본값으로 일정 추가 입력창을 연다. 일정·할일 탭, 필수 제목, 하루 종일, 시작·종료 날짜와 시간, 선택 장소·메모를 입력한다. 종일 일정에서 사용자가 고른 종료 날짜는 포함되는 날짜이며, 저장 요청에는 다음 날을 배타적 종료일로 보낸다. 좁은 화면에서는 날짜·시간을 세로로 배치하고 입력 영역을 스크롤하며 저장·취소 버튼은 계속 표시한다.

새 입력창의 서버 생성 요청은 `calendarId: "primary"`를 유지하며 `category`는 `일정` 또는 `할일`이다. 장소는 `location`, 메모는 `description`으로 전달한다. 서버는 이 필드들을 Google에 전달하고 조회 응답에도 유지해야 한다. 이 저장소에는 서버 구현이 없으므로 실제 서버의 해당 필드 지원 여부는 별도 확인이 필요하다. 기존 서비스 호출에서 유형을 지정하지 않으면 이전처럼 `category: "Google"`을 사용한다.

Google 직접 저장에서는 `location`, `description`과 `extendedProperties.private.inbbiCategory`를 사용한다. 조회 시 이 속성으로 앱의 일정·할일 유형을 복원한다. 할일은 Google 기본 캘린더에 저장되는 일정이며 Google Tasks 연동은 포함하지 않는다. [Google Calendar 일정 필드](https://developers.google.com/workspace/calendar/api/v3/reference/events)


## 저장 대상 선택

일정 추가 입력창의 메모 아래에서 `내 캘린더에만 저장` 또는 `구글 캘린더에도 저장`을 선택한다. 기본 선택은 기존 동작인 Google 저장이다. 앱 전용 일정은 기기 로컬 저장이 아닌 로그인 계정의 앱 서버 저장을 사용하며, 다른 기기에서는 같은 계정으로 월별 조회하여 확인한다.

앱 전용 저장의 새 서버 계약은 `POST /api/v1/calendar/app-events`이다. 앱 Bearer 인증을 사용하며 JSON은 `title`, `category`, `allDay`, `start`, `end`, 선택 `location`·`description`이다. `calendarId`를 보내지 않는다. 서버는 인증된 사용자에게 속한 앱 DB 일정만 생성하고 Google API를 호출하지 않아야 한다. 성공 시 기존 일정 조회 항목과 같은 객체 한 개를 반환한다. `GET /api/v1/calendar/events`는 해당 계정의 앱 전용 일정도 반환해야 하며 Google 연결 해제 상태에서도 앱 전용 조회가 가능해야 한다. 사용자 간 일정 접근을 차단해야 한다.

Google 저장은 기존 `/api/v1/calendar/events` 경로 또는 Google 직접 쓰기를 사용한다. 앱 전용 저장 실패를 Google 저장으로 대체하지 않는다. 실제 캘린더 서버 구현은 이 저장소에 없으므로 `/app-events` 구현과 통합 조회 지원을 서버에 추가해야 앱 전용 저장 및 기기 간 복원을 사용할 수 있다. 현재 검증은 서비스 대역과 HTTP 모의 응답이며 실제 서버 저장·다른 기기 조회는 미검증이다.


## 상세보기의 수정·삭제

일정 카드와 미완료 목록에서 상세 창을 열고 수정·삭제할 수 있다. 수정창은 기존 제목, 종류, 날짜·시간, 종일 여부, 장소, 메모를 채운다. 기존 저장 대상을 바꾸지 않으며 강의·과제의 종류도 유지한다. 삭제는 확인창에서 승인한 뒤 실행하고 실패 시 상세 창에 오류를 표시해 재시도할 수 있다. 성공 후 해당 출처의 월별 목록을 갱신한다.

클라이언트가 요구하는 추가 서버 계약(서버 구현은 이 저장소에 없으므로 실제 지원 여부는 별도 검증 필요):

- 앱 전용: `PATCH /api/v1/calendar/app-events/{id}` 및 `DELETE /api/v1/calendar/app-events/{id}`. PATCH 본문·응답은 앱 전용 생성과 같다. 기존 완료 상태는 PATCH에서 변경하지 않는다.
- 서버 Google 기본 캘린더: 기존 `PATCH /api/v1/calendar/events/{id}`와 추가 `DELETE /api/v1/calendar/events/{id}`.
- DELETE는 본문 없이 요청하며 성공 시 2xx(예: 204)를 반환한다. 401/403은 인증 오류, 404는 대상 또는 API 없음으로 처리한다. 서버는 요청 계정의 소유권과 출처를 확인해야 한다.
- 서버 조회·생성·수정 응답에서 Google 일정은 `calendarId: "primary"`, 앱 전용 일정은 `calendarId` 없음 또는 null을 반환해야 한다. 클라이언트는 이 값으로 쓰기 경로를 구분하며 Google 연결 여부로 추측하지 않는다. 다른 캘린더 ID의 쓰기는 지원하지 않는다.

Google 직접 연결은 기본 캘린더의 `events.patch` 및 `events.delete`를 사용한다. 삭제 요청·빈 응답 형식은 [Google 공식 문서](https://developers.google.com/workspace/calendar/api/v3/reference/events/delete)를 따른다. 인증 토큰은 요청 헤더에만 사용한다.

디버그 샘플은 인증이나 외부 API 없이 메모리에서 수정·삭제한다. 수정된 완료 상태와 종일 날짜를 보존하고 월 이동·새로고침 후에도 동일 실행 중의 변경을 유지한다. 앱 재실행 시 샘플은 초기 상태로 돌아온다. 실제 서버·Google 계정의 수정·삭제 전달은 아직 검증하지 않았다.
