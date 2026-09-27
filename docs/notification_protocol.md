# 실시간 알림 프로토콜 (웹·iOS)

이 문서는 Flutter 앱이 현재 구현한 테스트 서버 계약이다. 사용자 인증 서버와 상세 조회 API는 아직 저장소에 없다. 앱 설정의 디버그 전용 입력창에서 테스트 계정 액세스 토큰을 **메모리에서만** 사용한다. 앱에 입력한 토큰은 저장하거나 로그에 기록하지 않는다.

## 실행 설정

`config/firebase.example.json`의 `NOTIFICATION_WS_URL`과 `NOTIFICATION_API_URL`을 플랫폼별 `.local.json` 파일에 설정한다. 운영 연결은 `wss://`와 `https://`만 허용한다. REST 기본 URL은 경로 `/`로 끝나야 한다. 브라우저 서버는 테스트 앱 출처에 대해 CORS를 허용해야 한다.

```sh
flutter run -d chrome --dart-define-from-file=config/firebase.web.local.json
```

설정 > **테스트 서버 실시간 알림**에서 테스트 계정 토큰을 입력해 연결한다. 기기 ID는 설치/브라우저 단위로 생성해 로컬에 보관한다. 인증된 사용자의 내부 알림 목록과 목록 커서는 계정별로 분리된다. 실제 로그인 연동 때는 `NotificationRealtimeService.start(accessToken, deviceId)`를 호출하고, 토큰 갱신 시 `refreshCredentials()`를 호출한다. 로그아웃 때 `stop()`을 호출한다. 현재 로그인 화면은 인증하지 않는 목업이므로 사용자가 직접 테스트 토큰을 입력해야 한다.

## WebSocket

서버 경로: `wss://<host>/ws`. 소켓 연결 후 클라이언트가 다음 텍스트 프레임을 전송한다.

```json
{"type":"auth","accessToken":"<실제 테스트 계정 토큰>","deviceId":"<기기 ID>"}
```

서버는 인증 결과를 보내야 하며, 성공 전에는 사용자 알림을 전송하지 않는다.

```json
{"type":"auth.result","success":true,"userId":"test-user"}
```

실패 응답은 `{"type":"auth.result","success":false,"errorCode":"INVALID_TOKEN"}`이며 앱은 자동 재접속을 멈추고 다시 로그인을 안내한다. 소켓 연결 및 인증 응답 제한 시간은 각각 10초다. 비정상 종료 시 재접속은 1, 2, 4, 8, 16, 30초 순서이며 인증 성공 시 카운터를 초기화한다. 앱이 비활성화되면 소켓을 닫고, 복귀·네트워크 변경 시 다시 연결한다. 네트워크 종류 변화는 인터넷 접속 성공을 보장하지 않으므로 연결 실패는 계속 재시도한다.

알림 텍스트 프레임:

```json
{"type":"notification","eventId":"event-001","eventType":"notice.created","version":1,"title":"새 공지","body":"공지사항이 등록되었습니다.","target":{"type":"notice","id":"notice-001"},"deepLink":"/notices/notice-001","occurredAt":"2026-09-27T02:10:00Z"}
```

`occurredAt`은 시간대가 포함된 UTC ISO 8601 문자열로 전송한다. 현재 앱은 `deepLink`를 임의 라우트로 실행하지 않는다. `notice.*`는 공지 탭, `schedule.*`와 `assignment.*`는 캘린더 탭, 알 수 없는 이벤트는 알림 목록 탭으로 이동한다. 저장소에 항목별 상세 화면과 상세 조회 API가 없기 때문에 `target.id`는 목록에 보존하고 상세 이동은 후속 연동 지점으로 남겨 둔다.

유효한 알림을 로컬 저장소에 등록한 뒤에는 다음 ACK를 보낸다. 같은 ID/버전을 이미 저장했어도 ACK를 다시 보낼 수 있다.

```json
{"type":"notification.ack","eventId":"event-001","status":"listed","receivedAt":"2026-09-27T02:10:01Z"}
```

같은 결과를 `POST /api/v1/notifications/{eventId}/receipts`에도 전달한다. 이 API는 요청 중복을 허용해야 한다. 실패한 REST receipt는 현재 앱에 영구 큐로 저장하지 않는다. `opened` 상태는 알림을 눌렀을 때 전송한다. 상세 화면이 없으므로 `deep_link_completed`는 아직 전송하지 않는다.

## 목록 API

인증: `Authorization: Bearer <accessToken>`.

`GET /api/v1/notifications` 또는 `GET /api/v1/notifications?cursor=<cursor>`.

```json
{"items":[{"type":"notification","eventId":"event-001","eventType":"notice.created","version":1,"title":"새 공지","body":"공지사항이 등록되었습니다.","target":{"type":"notice","id":"notice-001"},"deepLink":"/notices/notice-001","occurredAt":"2026-09-27T02:10:00Z"}],"nextCursor":"cursor-002"}
```

`nextCursor`가 `null` 또는 빈 문자열이면 현재 끝이다. 서버 커서는 이전 응답을 다시 읽어도 안전한 **증분 위치**여야 한다. 앱은 각 페이지의 모든 항목을 저장한 다음에만 사용자별 커서를 저장한다. 페이지 처리 중 오류가 나면 커서를 진행하지 않고 재접속 시 다시 가져온다. 한 번의 연결에서 최대 50페이지를 읽는다. 서버가 최종 페이지에서도 다음 증분 위치를 반환하면 이후 복구가 효율적이다. 목록 조회는 WebSocket 인증 성공 후, 재접속 후에 수행한다.

같은 계정의 `eventId`에서 높은 `version`만 기존 항목을 갱신한다. 같은/낮은 버전은 무시하고 읽음 상태를 유지한다. 새 버전에도 읽음 상태를 보존한다. 버전 상승을 새 미확인 알림으로 처리해야 한다면 서버·앱 계약을 바꿔야 한다.

## FCM

서버는 WebSocket 연결 여부와 관계없이 필요한 시스템 푸시를 발송한다. FCM `data` 값은 문자열만 허용되므로 `version`은 `"1"`, `target`은 JSON 문자열로 인코딩한다. `eventId`, `eventType`, `title`, `body`, `deepLink`, `occurredAt`은 WebSocket/목록 API와 일치시킨다. 시스템 표시용 `notification.title/body`도 포함한다. 이 저장소의 `tool/push_server/server.py`는 해당 형식의 즉시 발송을 제공한다. Flutter의 공통 파서가 문자열 버전·target을 변환한다. iOS·웹 실제 전달은 Firebase/APNs/브라우저 설정이 필요하다.

## 기기 토큰과 receipt API

알림 종류 설정은 앱에서 `deadline`, `course`, `notice`, `other` 중 여러 항목을 선택한다. 앱은 선택값을 로컬에 보관하고 내부 알림 목록·배지·새 수신 저장에 적용한다. 인증된 실시간 서버에는 로그인 직후와 설정 변경 직후 다음 요청을 보낸다.

```http
PUT /api/v1/notification-preferences
Authorization: Bearer <accessToken>
Content-Type: application/json

{"enabledKinds":["deadline","course","notice","other"]}
```

서버는 이 값을 사용자별로 저장하고 **FCM 발송 전에** 이벤트 종류를 검사해야 한다. 기존 서버 API와 테스트 푸시 발송 서버에는 아직 이 엔드포인트 및 발송 필터가 없다. 따라서 서버가 이 계약을 구현하기 전에는 앱이 백그라운드이거나 종료된 동안 시스템 알림의 종류별 차단을 보장할 수 없다. 푸시의 `notification` 페이로드는 백그라운드에서 운영체제가 표시할 수 있다.

- `PUT /api/v1/devices/{deviceId}/fcm-token`, 본문 `{"token":"<FCM 토큰>"}`: 로그인 상태에서 등록·갱신.
- `DELETE /api/v1/devices/{deviceId}/fcm-token`: 알림 끄기 또는 연결 해제 시 해제.
- `POST /api/v1/notifications/{eventId}/receipts`, 본문 `{"status":"listed|opened","receivedAt":"<UTC ISO 8601>"}`.

모든 API는 계정 토큰으로 인증하고 해당 `deviceId`와 사용자 소유권을 확인해야 한다. FCM 토큰은 다른 계정에 재등록되면 이전 계정과 분리해야 한다. 서버는 일정 변경·취소 시 예약된 FCM을 갱신·취소해야 한다. 이 저장소의 테스트 발송 서버는 이러한 계정 API와 일정 예약을 제공하지 않는다.

## 검증 범위

검증 결과 (2026-09-27): `flutter analyze` 통과, `flutter test` 29개 통과, Python 테스트 6개 통과. 웹 릴리스 빌드와 iOS 서명 없는 빌드도 성공했다. 모의 소켓·HTTP 테스트에서 인증 전 메시지 차단, 인증 실패, 소켓 ACK, REST receipt, 커서 복원, 앱 복귀 재접속, 계정별 목록 분리, FCM 형식 파싱, 같은 이벤트의 버전 역전 및 읽음 유지, 토큰 등록·해제를 확인했다. 실제 WSS/REST 서버 주소와 테스트 계정 토큰이 없어 실제 서버 연결·브라우저/기기 수신은 미검증이다.

공식 참고: [web_socket_channel](https://pub.dev/packages/web_socket_channel), [connectivity_plus](https://pub.dev/packages/connectivity_plus), [FCM 수신](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
