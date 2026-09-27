# 캘린더 클라이언트 연결 방법

현재 앱은 앱 서버 일정 API와 Google Calendar API를 각각 조회해 화면에서 합친다. 앱 서버는 아직 이 저장소에 없고 로그인 화면도 목업이다. 따라서 서버 주소·실제 로그인 토큰·Google OAuth 클라이언트 설정이 없으면 캘린더에는 임의의 일정이 표시되지 않는다.

## 앱 서버 계약

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

Google Cloud 테스트 프로젝트에서 Calendar API를 사용 설정하고 Android, iOS, 웹용 OAuth 클라이언트를 등록한다. 앱은 `calendar.events.readonly`만 요청한다. 웹 클라이언트 ID는 `GOOGLE_WEB_CLIENT_ID`, iOS 클라이언트 ID는 `GOOGLE_IOS_CLIENT_ID`로 전달한다. Android에서는 등록된 패키지명·서명 SHA와 웹 클라이언트 ID가 맞아야 한다. iOS는 `Info.plist`의 URL scheme에 해당 클라이언트의 reversed client ID도 등록해야 한다. 이 값들은 테스트 프로젝트에서 얻어야 하므로 저장소에 실제 값을 넣지 않는다. [Flutter google_sign_in](https://pub.dev/packages/google_sign_in), [Android 설정](https://pub.dev/packages/google_sign_in_android), [iOS 설정](https://pub.dev/packages/google_sign_in_ios)

```sh
flutter run -d chrome \
  --dart-define=CALENDAR_API_URL=https://your-test-server.example/ \
  --dart-define=GOOGLE_WEB_CLIENT_ID=your-web-client-id
```

설정 화면의 `Google Calendar 연동` 행에는 미연동 상태부터 `Google 로그인` 버튼이 표시된다. 웹에서는 Google이 제공하는 로그인 버튼이 같은 행에 바로 표시되며, 그 버튼으로 계정을 선택한다. 웹의 계정 로그인과 Calendar API 접근 동의는 Google SDK에서 분리되어 있으므로 로그인 후 같은 행에 나타나는 `일정 권한 허용`을 눌러 동의한다. Android·iOS에서는 로그인 요청에 일정 읽기 권한을 함께 전달한다. 토큰이 만료되면 다시 권한을 요청한다. Google 계정 연결 없이도 앱 서버 일정 조회는 별도로 동작한다.

### 로그인했는데 일정이 보이지 않을 때

Google 로그인은 계정 확인이고, 일정 조회에는 별도의 `calendar.events.readonly` 동의가 필요하다. 캘린더 탭에서 `Google 일정 조회 권한 허용`을 눌러 동의한 뒤 현재 월의 날짜를 확인한다. 앱은 연결한 계정의 **기본 캘린더(`primary`)**와 현재 표시 중인 월만 조회하며, 선택한 날짜의 일정만 오른쪽/아래 목록에 보여 준다. 앱 서버 주소가 설정되지 않은 상태는 캘린더 화면에서 오류로 표시하지 않으며 Google 조회를 막지 않는다.

권한을 허용했는데도 `Google 일정 접근이 거부됐어요(403)`가 표시되면 Google Cloud에서 Calendar API 사용 설정, OAuth 동의 화면의 범위, 테스트 사용자를 확인한다. API 응답이 0개면 캘린더 탭에 `이 달의 Google 기본 캘린더에 일정이 없어요`가 표시된다. 응답은 있는데 날짜 형식을 처리하지 못하면 오류를 표시한다. 다른 캘린더의 일정이나 Google Tasks의 할 일은 현재 연동 범위에 포함되지 않는다.

## 현재 확인 범위

서비스 대역 테스트로 서버·Google 페이지 조회, 인증 오류, 종일 일정 종료일, 출처 병합과 부분 실패를 확인한다. 캘린더 화면은 너비 390·839·840·1280에서 검사한다. 실제 서버와 Google 테스트 계정이 준비되기 전에는 실계정 연결·전달 테스트와 앱 서버의 생성·수정·삭제 검증을 완료할 수 없다.
