# 캘린더 클라이언트 연결 방법

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

연결 시작 버튼은 설정 탭의 `Google Calendar 연동`에 있다. Android·iOS에서는 Google 계정 선택 직후 서버 인증 코드를 요청한다. 웹에서는 Google 제공 로그인 버튼으로 계정을 선택한 뒤 서버 인증 코드를 요청한다. 브라우저가 추가 사용자 동작을 요구하거나 코드 발급에 실패하면 설정 탭의 `Google 연결 계속` 버튼으로 재시도한다. 이 제한 때문에 웹에서 모든 계정에 대해 한 번의 클릭만으로 완료됨을 보장할 수는 없다. 서버가 연결을 확인하면 앱은 서버 일정만 표시한다. 연결 후에는 설정의 `Google Calendar 연동` 행에서 연결을 해제한다.

### 로그인했는데 일정이 보이지 않을 때

Google 로그인은 계정 확인이고, 일정 조회·생성·수정에는 별도의 `calendar.events` 동의가 필요하다. 설정 탭에서 `일정 권한 허용`을 눌러 동의한 뒤 현재 월의 날짜를 확인한다. 앱은 연결한 계정의 **기본 캘린더(`primary`)**와 현재 표시 중인 월만 조회하며, 선택한 날짜의 일정만 오른쪽/아래 목록에 보여 준다. 앱 서버 주소가 설정되지 않은 상태는 캘린더 화면에서 오류로 표시하지 않으며 Google 조회를 막지 않는다.

생성·수정은 아직 UI 없이 `CalendarController.createGoogleEvent(draft)`와 `updateGoogleEvent(eventId, draft)`로 제공한다. `CalendarEventDraft`는 제목, 시작·종료, 종일 여부를 받고 종료 시각/날짜는 포함하지 않는다. 서버 연결 중에는 앱 Bearer 토큰으로 `POST`·`PATCH`를 사용하고, 서버 미연결 테스트 모드에서는 Google API의 `events.insert`·`events.patch`를 직접 호출한다. 수정 시 화면에서 받은 `server:<id>` 또는 `google:primary:<id>`를 사용한다. 성공 후 현재 월을 다시 조회한다. 삭제, 참석자·반복 일정·다른 캘린더 수정은 아직 지원하지 않는다. [Google 생성 API](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert), [Google 수정 API](https://developers.google.com/workspace/calendar/api/v3/reference/events/patch)

권한을 허용했는데도 `Google 일정 접근이 거부됐어요(403)`가 표시되면 Google Cloud에서 Calendar API 사용 설정, OAuth 동의 화면의 범위, 테스트 사용자를 확인한다. API 응답이 0개면 캘린더 탭에 `이 달의 Google 기본 캘린더에 일정이 없어요`가 표시된다. 응답은 있는데 날짜 형식을 처리하지 못하면 오류를 표시한다. 다른 캘린더의 일정이나 Google Tasks의 할 일은 현재 연동 범위에 포함되지 않는다.

## 현재 확인 범위

서비스 대역 테스트로 서버·Google 페이지 조회, 인증 오류, 종일 일정 종료일, 출처 병합과 부분 실패를 확인한다. 캘린더 화면은 너비 390·839·840·1280에서 검사한다. 실제 서버와 Google 테스트 계정이 준비되기 전에는 실계정 연결·전달 테스트와 앱 서버의 생성·수정·삭제 검증을 완료할 수 없다.
