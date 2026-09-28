# RHEL 개인 PC 캘린더 테스트 서버 계획

작성 기준: 2026-09-28. 이 문서는 **별도 API 서버 프로젝트**를 RHEL 노트북에서 실행하고, 다른 사용자가 인터넷을 통해 인삐 앱으로 접속해 Google 캘린더 연동을 검증하는 계획이다. 이 저장소에는 API 서버 구현이 없다.

## 1. 목표와 범위

- 테스트 사용자 A·B가 각각 인삐에 로그인하고 자기 Google 기본 캘린더의 일정만 조회한다.
- 최초 연결 때 Google 계정 선택과 일정 조회·수정 권한 동의를 요청한다. 서버는 사용자별 갱신 토큰을 보관하고 재시작 후에도 연결을 복원한다.
- 외부 사용자는 `https://api.example.com/` 같은 고정 HTTPS 주소로 접근한다. 외부에 RHEL PC의 IP와 서버 포트를 직접 공개하지 않는다.
- 현재 연동 범위는 **기본 캘린더의 월별 일정 조회·생성·수정**이다. 삭제, 다른 캘린더와 Google Tasks는 이번 검증에서 제외한다. 생성·수정 UI는 아직 없으므로 서비스/API 테스트로 검증한다.
- 서버는 테스트용이며 운영 서비스의 가용성·백업·모니터링 수준을 전제로 하지 않는다. 노트북 전원·인터넷·Tunnel이 끊기면 외부 접속도 중단된다.

## 2. 구성

```text
테스터의 웹/Android/iOS 앱
  └─ HTTPS https://api.example.com/
       └─ Cloudflare Tunnel
            └─ RHEL PC의 cloudflared
                 └─ http://127.0.0.1:<내부 포트> API 서버
                      ├─ 테스트 사용자 인증/세션
                      ├─ 사용자별 Google 연결 상태와 암호화된 갱신 토큰
                      └─ Google Calendar API
```

Cloudflare의 **published application route**는 공개 호스트 이름을 로컬 HTTP 서비스에 연결한다. RHEL 서버는 `127.0.0.1`에만 바인딩하고 노트북의 공유기 포트 포워딩은 설정하지 않는다. 외부 URL에는 포트가 없지만, `cloudflared`가 로컬 서버를 찾기 위한 **내부 포트는 필요**하다. 처음에는 환경 변수로 `8000`을 정하고, 바꾸면 API 서버와 Tunnel의 Service URL을 함께 변경한다. 매 실행마다 임의 포트를 쓰려면 서버 기동 시 선택된 포트를 Tunnel 설정에 자동 반영하는 추가 스크립트가 필요하므로 초기 테스트에는 사용하지 않는다. [Cloudflare 라우팅 문서](https://developers.cloudflare.com/tunnel/concepts/routing/), [지원 서비스 주소](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/routing-to-tunnel/protocols/)

## 3. 시작 전 결정·준비

| 항목 | 준비 내용 | 완료 기준 |
|---|---|---|
| 도메인 | 관리 가능한 테스트용 `api.example.com` 대체 호스트 이름 | 외부 DNS와 HTTPS 접속 가능 |
| RHEL PC | 지원 버전의 RHEL, 안정적인 전원·인터넷, 테스트 중 절전 해제 | 재부팅 후 서버와 Tunnel 복구 확인 |
| API 프로젝트 | 실행 방법, 환경 변수, 의존성 고정, `/health` 제공 | 로컬 요청에 200 응답 |
| 앱 인증 | 테스트 사용자 A·B의 실제 로그인 API와 사용자별 앱 토큰 | 앱이 로그인 결과를 `CalendarController.setAppToken`에 전달 |
| Google Cloud | 테스트 OAuth 프로젝트, Calendar API, 플랫폼별 클라이언트, 테스트 사용자 | A·B가 본인 계정으로 동의 가능 |
| 저장소 | 사용자·Google 연결 상태·갱신 토큰의 영속 저장소 및 암호화 키 | API 서버 재시작 후에도 연결 유지 |
| 테스트 데이터 | A·B 기본 캘린더에 서로 다른 제목의 이번 달 일정, 종일 일정, 월 경계 일정 | 계정별 데이터 구별 가능 |

**필수 선행 조건:** 현재 `lib/features/auth/login_page.dart`는 목업으로, ID/비밀번호를 검사하거나 앱 토큰을 발급하지 않는다. 이것을 실제 로그인 API에 연결하기 전에는 사용자 A·B의 분리 테스트가 성립하지 않는다. Google 계정 이메일을 앱 사용자 ID 대신 신뢰해서는 안 된다.

## 4. 별도 API 서버 계약

앱에 이미 구현된 요청 형식을 [캘린더 클라이언트 문서](calendar_development.md)와 맞춘다.

| API | 인증 | 동작 |
|---|---|---|
| `GET /health` | 없음 | 프로세스 상태만 반환. 사용자·토큰·설정 정보 노출 금지 |
| 앱 로그인 API | 서버 프로젝트에서 정의 | 자격 검증 후 A·B에 서로 다른 앱 인증 토큰 발급 |
| `POST /api/v1/calendar/google/connection` | 앱 Bearer 토큰 | `authorizationCode`를 Google과 교환하고 **인증된 앱 사용자**에게 연결. 성공 2xx |
| `GET /api/v1/calendar/google/connection` | 앱 Bearer 토큰 | 연결됨은 `{"connected":true}`, 미연결은 `{"connected":false}` 반환 |
| `DELETE /api/v1/calendar/google/connection` | 앱 Bearer 토큰 | 현재 사용자의 저장된 Google 연결·갱신 토큰 제거. 성공 2xx |
| `GET /api/v1/calendar/events` | 앱 Bearer 토큰 | `timeMin`, `timeMax`, 선택적 `cursor`를 받아 해당 사용자의 일정만 반환 |
| `POST /api/v1/calendar/events` | 앱 Bearer 토큰 | 해당 사용자 Google 기본 캘린더에 일정 생성 후 일정 객체 반환 |
| `PATCH /api/v1/calendar/events/{id}` | 앱 Bearer 토큰 | 해당 사용자 Google 기본 캘린더의 기존 일정 수정 후 일정 객체 반환 |

`GET /events`의 응답은 `{"items":[...],"nextCursor":null}`이다. 시간 지정 일정은 UTC 오프셋이 있는 ISO 8601, 종일 일정은 `YYYY-MM-DD`의 시작·배타적 종료 날짜를 사용한다. 인증 실패는 401/403, Google 연결 없음은 빈 목록 또는 서버 프로젝트에서 합의한 명시적 상태로 처리한다. API는 클라이언트가 보낸 사용자 ID를 신뢰하지 않고 **검증된 앱 토큰의 주체**로 연결과 조회를 제한한다.

Google 인증 코드는 한 번만 교환하고 요청 본문·응답·로그에 남기지 않는다. 서버에서 갱신 토큰을 암호화 저장하고 키는 데이터베이스와 별도 위치의 서버 비밀 설정으로 보관한다. 토큰 재발급 시 새 갱신 토큰이 제공되지 않으면 기존 유효 토큰을 무조건 지우지 않는다. 권한 철회·토큰 만료 시 연결 필요 상태를 반환한다. Google은 오프라인 접근 시 갱신 토큰을 이용해 사용자 없이 액세스 토큰을 갱신할 수 있다고 설명한다. [Google 서버 OAuth 가이드](https://developers.google.com/identity/protocols/oauth2/web-server), [OAuth 보안 권장사항](https://developers.google.com/identity/protocols/oauth2/resources/best-practices)

## 5. RHEL PC 설치·기동 순서

1. **로컬 API 확인:** 별도 프로젝트를 RHEL에 설치하고 환경 변수로 내부 포트를 지정해 `127.0.0.1:<포트>`에서 실행한다. 같은 포트의 기존 서비스가 있으면 중지하거나 다른 포트를 선택한다. `curl http://127.0.0.1:<포트>/health`가 200을 반환하는지 확인한다.
2. **영속 저장소 확인:** 서버 프로세스를 중지·재시작해 테스트 사용자와 Google 연결 상태가 남는지 확인한다. 데이터베이스·암호화 키에 대한 파일 접근 권한을 서버 계정으로 제한한다. 비밀 설정 파일은 Git에 올리지 않는다.
3. **Tunnel 설치:** Cloudflare 계정에서 named tunnel을 만들고 RHEL의 `cloudflared`를 연결한다. Published application route에 공개 호스트 `api.example.com`과 Service URL `http://127.0.0.1:<포트>`를 지정한다. 외부 공개 전에 인증된 API가 무인증으로 동작하지 않는지 확인한다. [Cloudflare Tunnel 생성 절차](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/)
4. **서비스 자동 시작:** API 서버와 `cloudflared`를 각각 systemd 서비스로 관리하고 재부팅 후 자동 시작·상태 확인을 설정한다. Tunnel만 Healthy여도 로컬 API가 정상이라는 뜻은 아니므로 두 서비스를 따로 점검한다. [Cloudflare Linux 서비스 안내](https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/as-a-service/linux/), [원본 연결 점검](https://developers.cloudflare.com/tunnel/troubleshooting/https-origins/)
5. **외부망 확인:** RHEL에서는 로컬 `/health`를 확인하고, **같은 Wi-Fi가 아닌** 휴대폰 모바일 데이터에서 `https://api.example.com/health`를 연다. 다음으로 무인증 `/events` 요청은 401, A의 토큰으로 A의 데이터만 나오는지 확인한다.
6. **앱 설정:** 앱 실행/빌드에 `--dart-define=CALENDAR_API_URL=https://api.example.com/`을 넣는다. 앱 로그인 성공 토큰을 `CalendarController.setAppToken`에 전달한다. 웹 앱은 별도의 안정적인 HTTPS 주소를 사용하는 편이 OAuth 승인 원본 관리에 유리하다.

RHEL 방화벽에서 내부 API 포트를 외부에 열 필요는 없다. 서버와 Tunnel이 같은 PC에서 loopback으로 통신한다. SELinux 오류가 발생하면 감사 로그로 원인을 확인하고 필요한 정책만 조정한다. SELinux를 전체 비활성화하는 것을 설치 절차로 삼지 않는다.

## 6. 웹·모바일 접속 조건

- **웹:** 브라우저의 앱 원본과 `https://api.example.com`이 다르면 서버에서 정확한 앱 원본만 CORS 허용한다. `Authorization`·`Content-Type` 헤더와 `POST`·`GET`·`DELETE`·`OPTIONS` 사전 요청을 처리한다. `*`와 인증 정보 허용 조합은 사용하지 않는다.
- **Google OAuth:** 웹 앱의 승인된 JavaScript 원본은 실제 웹 앱 주소와 정확히 일치시킨다. 서버 리디렉션 흐름을 선택한다면 승인된 리디렉션 URI도 정확히 등록한다. localhost 임의 포트는 등록된 원본과 맞지 않을 수 있다.
- **Android/iOS:** `CALENDAR_API_URL`은 HTTPS 도메인으로 지정한다. 각 플랫폼의 OAuth 클라이언트 설정을 테스트 빌드와 일치시킨다. RHEL의 `127.0.0.1`은 모바일 기기의 로컬 주소가 아니므로 앱 설정에 넣지 않는다.
- **공개 범위:** `/health` 외 캘린더 API는 앱 인증 필수다. 테스트 사용자만 사용하고 서버에 속도 제한·요청 크기 제한을 둔다. Cloudflare Access를 추가할 경우 앱 API의 인증 헤더 및 모바일 접속과 충돌하지 않도록 별도 검증한다.

## 7. 실행 시나리오와 완료 기준

| 순서 | 실행 | 기대 결과 |
|---|---|---|
| 1 | A 로그인 → 캘린더 열기 | 미연결이면 `Google 캘린더 연결` 표시 |
| 2 | A가 Google 계정 선택·동의 | 서버 연결 API 성공, A의 이번 달 일정 표시 |
| 3 | B 로그인 → 다른 Google 계정 연결 | B에게 B 일정만 보이고 A 일정은 보이지 않음 |
| 4 | A·B 각각 재로그인 | `GET /connection`에서 연결 복원, 연결 버튼 재요청 없음 |
| 5 | API 서버 재시작 후 A·B 조회 | 저장된 연결로 각자 일정 조회 성공 |
| 6 | A의 Google 연결 해제 | A만 연결 해제되고 B는 유지 |
| 7 | 권한 거부·토큰 철회·서버/인터넷 일시 중단 | 앱이 중단되지 않고 재시도 또는 재연결 가능 |
| 8 | 날짜·시간대·종일·월 경계·중복 확인 | 표시 월/날짜가 Google 기본 캘린더와 일치하고 동일 일정이 중복되지 않음 |
| 9 | A가 테스트 일정을 생성·수정하고 B가 조회 | A의 일정만 변경되고 B의 일정에는 영향 없음 |

각 실행에는 OS·브라우저/앱 버전, 테스트 사용자 식별자(실제 이메일 대신 A/B), 시각, 기대/실제 결과, 오류 코드, 스크린샷을 기록한다. 인증 코드·앱 토큰·Google 토큰·Tunnel 자격 증명은 기록하지 않는다.

## 8. 진행 순서와 아직 미완료인 항목

- [ ] 별도 API 프로젝트에서 앱 로그인, 사용자별 저장소, Google 코드 교환과 일정 API 구현
- [ ] 앱의 목업 로그인에서 실제 앱 로그인 API 호출 및 `setAppToken` 전달
- [ ] RHEL 로컬 `/health`와 서비스 재시작 확인
- [ ] Cloudflare Tunnel 공개 호스트와 휴대폰 모바일 데이터 접속 확인
- [ ] 웹·Android·iOS OAuth 테스트 설정 및 두 사용자 연결 확인
- [ ] 계정 격리, 서버 재시작, 권한 거부·철회, 시간대/종일 일정 검증

이 항목들은 **계획**이며, 서버·계정·외부 접속 테스트가 완료되기 전에는 완료로 표시하지 않는다.
