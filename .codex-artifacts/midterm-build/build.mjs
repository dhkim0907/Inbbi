import fs from 'node:fs/promises';
import { GlobalFonts } from '@napi-rs/canvas';
import { Presentation, PresentationFile } from '@oai/artifact-tool';
import { finalizePresentation } from '/Users/dohyun/.codex/plugins/cache/openai-primary-runtime/presentations/26.1015.12040/skills/presentations/container_tools/artifact_tool_utils.mjs';

const ROOT='/Users/dohyun/workspace/Inbbi';
const TMP=ROOT+'/.codex-artifacts/midterm-build';
const SKILL='/Users/dohyun/.codex/plugins/cache/openai-primary-runtime/presentations/26.1015.12040/skills/presentations';
for (const w of ['Regular','Medium','SemiBold','Bold','ExtraBold']) GlobalFonts.registerFromPath(`${ROOT}/assets/fonts/NotoSansKR-${w}.ttf`, 'Noto Sans KR');
const p=Presentation.create({slideSize:{width:1280,height:720}});
const C={blue:'#346CB2',ink:'#172D4B',muted:'#607087',paper:'#F6F8FC',white:'#FFFFFF',teal:'#21846C',amber:'#A66C09'};
const font='Noto Sans KR';
function text(s,t,x,y,w,h,size=26,color=C.ink,bold=false){
  const a=s.shapes.add({geometry:'textbox',name:t.slice(0,30),position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none',width:0}});
  a.text=t;a.text.style={typeface:font,fontSize:size,color,bold,wrap:true,verticalAlignment:'middle',insets:0};return a;
}
function slide(title,notes,dark=false){const s=p.slides.add();s.background.fill=dark?C.ink:C.paper;
  text(s,title,72,48,1136,82,44,dark?C.white:C.ink,true);
  text(s,String(p.slides.items.length).padStart(2,'0'),1158,660,50,28,17,dark?'#9BAFCB':C.muted);
  s.speakerNotes.text=notes; return s;}
function para(s,heading,body,y,x=72,w=1080){text(s,heading,x,y,w,44,30,C.blue,true);text(s,body,x,y+52,w,80,26,C.ink);}
async function img(s,path,x,y,w,h){const b=await fs.readFile(path);s.images.add({blob:b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),contentType:'image/png',alt:path.split('/').pop(),fit:'contain',position:{left:x,top:y,width:w,height:h}});}
const refs=(...a)=>'\n\n근거: '+a.map(x=>ROOT+'/'+x).join('\n');

// 1
let s=slide('Inbbi', '약 35초. 안녕하세요. 학사 정보와 I-Class 정보를 한곳에서 관리하는 인삐 프로젝트의 중간 진행 상황을 발표하겠습니다. 현재는 Flutter 클라이언트의 핵심 화면과 캘린더·알림 서비스 로직을 구현했습니다. 오늘은 기획 의도, 구현 화면, 기술 구조, 검증 결과와 남은 계획 순으로 설명하겠습니다.'+refs('README.md'),true);
text(s,'학사 정보와 일정을 한곳에서',72,206,950,90,54,C.white,true);
text(s,'프로젝트 중간 발표',72,318,800,48,30,'#C9D7EA');
text(s,'2026.10.31',72,580,500,40,23,'#9BAFCB');
await img(s,ROOT+'/assets/icons/app_icon.png',1010,455,170,170);

// 2
s=slide('기획 배경과 목표','약 50초. 인삐는 I-Class와 학사 정보를 통합 관리하기 위한 프로젝트입니다. 학생이 강의, 과제, 공지와 개인 일정을 각각 확인해야 한다는 상황을 문제로 설정했습니다. 이 부분은 사용자 조사 결과가 아니라 현재 프로젝트가 해결하려는 사용 시나리오입니다. 목표는 오늘 확인할 항목을 홈에서 보고, 날짜별 할 일을 캘린더로 관리하고, 새 소식은 알림으로 확인하는 흐름입니다. 마감 누락 감소와 확인 동선 단축은 기대 효과이며 아직 측정하지 않았습니다.'+refs('README.md','lib/features/home/home_dashboard_page.dart'));
text(s,'여러 곳의 학사 정보를\n매번 확인하는 학생을 위한 앱',72,170,1100,142,49,C.ink,true);
para(s,'통합 확인','홈에서 강의·과제·공지를 확인하고 날짜별 일정을 관리',356);
para(s,'알림으로 후속 행동 연결','새 소식을 확인한 뒤 관련 화면으로 이동',508);

// 3 native status table
s=slide('현재 개발 범위','약 55초. 구현 상태는 영역마다 다릅니다. 홈과 강의는 화면을 구성했고 실제 데이터 연결이 남아 있습니다. 캘린더는 월별 조회와 일정·할일 추가, 수정, 삭제를 처리합니다. Google 연결 클라이언트도 있으나 테스트 계정에서의 검증이 필요합니다. 공지는 검색과 분류, 수집처 설정을 구현했지만 실제 수집 서비스가 필요합니다. 내부 알림은 저장과 읽음, 중복 처리를 포함합니다. 외부 알림은 Firebase와 WebSocket 클라이언트가 있으며 실제 서버와 기기 수신 검증이 남았습니다. 전체 완료율은 계산하지 않았습니다.'+refs('README.md','lib/features/home/home_dashboard_page.dart','lib/features/course/course_management_page.dart','lib/features/notice_feed/notice_sources.dart'));
const vals=[['영역','현재 구현','남은 확인'],['홈·강의','대시보드·강의 화면','실제 데이터 연결'],['캘린더','일정 관리·Google 연결 클라이언트','계정 연동·서버 저장 검증'],['공지','검색·분류·수집처 설정','실제 공지 수집 서비스'],['앱 내부 알림','읽음·배지·로컬 저장·중복 처리','외부 수신과 통합 검증'],['외부·실시간 알림','FCM·WebSocket·HTTP 클라이언트','서버·플랫폼 설정 및 전달 검증']];
const tb=s.tables.add({rows:6,columns:3,left:72,top:174,width:1136,height:420,columnWidths:[215,485,436],values:vals});
tb.borders.assign({fill:'#DDE4EE',width:1,style:'solid'});
for(let r=0;r<6;r++)for(let c=0;c<3;c++){const cell=tb.getCell(r,c);cell.fill=r===0?C.ink:C.white;cell.text.style={typeface:font,fontSize:23,color:r===0?C.white:C.ink,bold:r===0};}
text(s,'실제 학사·공지 수집 서버와 앱 서버 구현은 현재 저장소에 포함되지 않음',72,617,1110,34,21,C.muted);

// 4 screenshots
s=slide('캘린더 구현 화면','약 65초. 화면은 현재 코드의 위젯 테스트에서 테스트 데이터로 캡처했습니다. 모바일과 데스크톱 모두 같은 기능을 제공하고 너비 840 논리 픽셀에서 레이아웃을 전환합니다. 월 이동과 날짜 선택, 종류별 필터, 기간 일정과 종일 일정을 표시합니다. 일정·할일 추가, 상세 조회, 수정·삭제 흐름도 구현했습니다. Google 기본 캘린더 조회와 쓰기 클라이언트를 분리했고, 실제 계정 연결, 권한 거부, 만료와 네트워크 실패는 통합 환경에서 확인할 예정입니다. 화면의 2026년 9월은 테스트용 날짜입니다.'+refs('test/features/calendar/calendar_figma_page_test.dart','lib/features/calendar/calendar_controller.dart','lib/features/calendar/calendar_event_writer.dart','lib/features/calendar/google_calendar_api.dart'));
await img(s,ROOT+'/build/ui_review/calendar-agenda-1207.png',72,160,642,438);
await img(s,ROOT+'/build/ui_review/calendar-390.png',753,154,180,462);
text(s,'월·날짜 탐색\n종류별 필터\n기간·종일 일정\n일정·할일 관리',975,200,245,290,27,C.ink,true);
text(s,'모바일·데스크톱 테스트 화면 / 테스트 데이터',72,620,1100,35,21,C.muted);

// 5 screenshots
s=slide('공지 모아보기와 수집처 설정','약 55초. 공지 화면에서는 검색어와 카테고리로 목록을 좁힐 수 있습니다. 수집처 등록 흐름은 이름과 URL 입력, 공지 항목의 제목과 링크 위치 선택, 미리보기와 저장으로 구성했습니다. 현재 미리보기와 목록은 예시 데이터를 사용합니다. 따라서 실제 웹사이트를 수집하고 최신 공지를 받아오는 부분까지 완료했다고 설명하지 않겠습니다. 이후 수집 서버와 연결하고 사이트 구조가 바뀔 때 설정과 오류를 어떻게 처리할지 확인해야 합니다.'+refs('lib/features/notice_feed/notice_sources.dart','lib/features/notice_feed/notice_source_dialogs.dart','test/features/notice_feed/notice_feed_page_test.dart'));
await img(s,ROOT+'/build/ui_review/notice-390.png',72,160,182,467);
await img(s,ROOT+'/build/ui_review/notice-locations-1207.png',298,164,600,430);
text(s,'검색·카테고리 필터',936,205,286,75,27,C.blue,true);
text(s,'이름·URL 등록\n제목·링크 위치 설정\n미리보기·로컬 저장',936,302,286,190,25);
text(s,'예시 데이터 기반 화면이며, 실제 공지 수집 서버 연동은 후속 과제',298,616,900,38,21,C.muted);

// 6
s=slide('알림 처리와 중복 방지','약 60초. 알림은 앱 내부 목록과 외부 전달 경로를 구분했습니다. 앱 내부에서는 읽음 상태와 배지, 목록 필터, 로컬 저장을 관리합니다. 같은 이벤트는 ID와 버전으로 비교해 중복을 막고 최신 버전이 오면 읽음 상태를 유지합니다. 외부 경로는 FCM 푸시와 WebSocket입니다. 연결이 끊긴 뒤에는 HTTP 목록과 커서로 누락된 알림을 복구하는 클라이언트가 있습니다. 로컬 예약 알림은 구현하지 않았으며 웹·iOS의 실제 전달과 앱 상태별 동작을 검증해야 합니다.'+refs('lib/features/notification/notification_service.dart','lib/features/notification/realtime/realtime_service.dart','lib/features/notification/push/push_service.dart','test/features/notification/realtime_test.dart'));
text(s,'앱 내부',72,174,500,60,38,C.blue,true);
text(s,'목록·필터·읽음 처리·배지\n계정별 로컬 저장\n이벤트 ID·버전으로 중복 제어',72,264,520,170,29);
text(s,'외부 수신',686,174,500,60,38,C.blue,true);
text(s,'FCM 푸시와 WebSocket\n재접속 시 HTTP로 누락 복구\n수신 확인·기기 토큰 관리',686,264,520,170,29);
text(s,'남은 검증',72,510,260,45,29,C.amber,true);
text(s,'웹·iOS 실제 전달, 권한 거부, 앱 상태별 수신과 화면 이동\n로컬 예약 알림은 현재 구현 범위에 포함되지 않음',72,565,1136,80,26);

// 7
s=slide('기술 구성과 책임 분리','약 55초. Flutter와 Dart로 Android, iOS, 웹을 대상으로 개발합니다. 기능별로 디렉터리를 나누고 공통 테마와 내비게이션을 재사용합니다. 화면에서는 Scope를 통해 상태를 받고, ChangeNotifier 기반 컨트롤러와 서비스가 상태를 관리합니다. API와 플랫폼 처리를 UI에서 분리해 실제 서버 대신 모의 구현으로 테스트할 수 있습니다. 외부 의존성에는 Google Calendar, Firebase, WebSocket과 앱 서버 API가 있습니다. 이 구조에서 현재 저장소가 제공하는 것은 주로 클라이언트와 로컬 푸시 테스트 도구입니다.'+refs('lib/app.dart','lib/core/widgets/main_tab_shell.dart','pubspec.yaml','lib/features/calendar/calendar_scope.dart','lib/features/notification/notification_scope.dart'));
para(s,'화면 계층','기능별 Flutter 화면과 공통 위젯·반응형 내비게이션',172);
para(s,'상태·서비스 계층','ChangeNotifier와 Scope / 캘린더·인증·알림 로직',326);
para(s,'연동·저장 계층','HTTP·Google Calendar·FCM·WebSocket / 로컬 저장',480);
text(s,'UI와 연동 로직을 분리해 모의 서비스로 동작을 검증',72,627,1120,37,23,C.blue,true);

// 8
s=slide('현재 검증 결과','약 60초. 발표 자료를 준비하며 현재 저장소에서 검증 명령을 직접 실행했습니다. 정적 분석은 문제없이 통과했습니다. 전체 Flutter 테스트에서는 163개가 통과했고 10개가 실패했습니다. 실패 항목에는 캘린더의 서버 연결 복원과 Google 설정 화면 관련 테스트가 포함됩니다. 또 공통 검증 스크립트는 기존 강의 화면의 서식 차이 때문에 첫 단계에서 중단됐습니다. 이 작업에서는 앱 코드를 수정하지 않았습니다. 자동 테스트와 실제 계정 및 기기 검증은 별도로 관리하며 실기기 전달은 이번에 실행하지 않았습니다.'+refs('tool/verify.sh','test/features/calendar/calendar_service_test.dart','test/features/notification/notification_service_test.dart','test/features/notification/push_service_test.dart'));
text(s,'163',72,175,470,125,104,C.blue,true);
text(s,'Flutter 테스트 통과',78,305,490,44,29);
text(s,'10',690,175,470,125,104,C.amber,true);
text(s,'Flutter 테스트 실패',696,305,490,44,29);
para(s,'정적 분석 통과','flutter analyze: No issues found',402);
text(s,'캘린더 연결 복원·Google 설정 관련 실패 포함\n공통 검증은 기존 서식 차이로 중단 / 실제 계정·기기 검증은 미실행',72,564,1136,81,25,C.muted);

// 9
s=slide('후반기 개발 계획','약 65초. 후반기 계획은 날짜가 정해진 일정이 아니라 개발 우선순위입니다. 먼저 기존 실패 테스트를 정리하고 Google 계정 연결과 앱 서버 계약을 테스트 환경에서 검증합니다. 이어 실제 공지 수집과 홈·강의 데이터를 연결합니다. 이후 웹과 iOS에서 권한 허용과 거부, 실행 중과 백그라운드, 종료 상태의 푸시 수신을 확인합니다. 마지막으로 일정 변경·삭제, 중복 수신, 네트워크 복구와 화면 이동까지 이어지는 시연을 준비하겠습니다. 완료 기준은 화면 존재가 아니라 실제 연결부터 사용자 확인까지 동작하는 것입니다.'+refs('AGENTS.md','README.md'));
const steps=[['01','기존 실패와 계정 연동','캘린더 실패 테스트 정리, Google 연결·조회·해제 확인'],['02','실제 데이터 연결','학사·공지 수집 서버와 홈·강의 데이터 연결'],['03','알림 전달 검증','웹·iOS에서 권한과 앱 상태별 수신·선택 확인'],['04','통합 시연 준비','일정 변경·삭제, 중복 수신, 네트워크 복구 확인']];
for(let i=0;i<steps.length;i++){const y=170+i*119;text(s,steps[i][0],72,y,90,60,40,C.blue,true);text(s,steps[i][1],204,y,990,43,29,C.ink,true);text(s,steps[i][2],204,y+48,990,44,25,C.muted);}

// 10
s=slide('중간 성과와 최종 목표','약 40초. 현재까지의 성과는 여러 학사 정보를 함께 보여주는 화면 기반, 일정 관리 기능, 그리고 알림의 읽음과 저장 및 중복 처리를 위한 서비스 구조를 갖춘 점입니다. 앞으로 실제 데이터와 서버를 연결하고 계정 및 기기 환경에서 전체 흐름을 확인해야 합니다. 최종 발표에서는 공지를 확인하고 일정을 관리한 뒤 알림을 통해 다시 관련 화면으로 이동하는 과정을 실제 테스트 환경에서 보여주는 것을 목표로 하겠습니다. 감사합니다. 질문 받겠습니다.'+refs('README.md','AGENTS.md'),true);
text(s,'핵심 화면과 서비스 로직 구현',72,190,1110,82,46,C.white,true);
text(s,'다음 단계는 실제 데이터 연결과\n계정·기기 환경에서의 통합 검증',72,330,1100,134,39,'#C9D7EA');
text(s,'질의응답',72,579,800,60,34,C.white,true);

await fs.mkdir(TMP,{recursive:true});
for(let i=0;i<p.slides.items.length;i++){
  const blob=await p.export({slide:p.slides.items[i],format:'png',scale:1});
  await fs.writeFile(`${TMP}/slide-${String(i+1).padStart(2,'0')}.png`,new Uint8Array(await blob.arrayBuffer()));
}
await fs.writeFile(TMP+'/montage.webp',new Uint8Array(await (await p.export({format:'webp',montage:true,scale:0.5})).arrayBuffer()));
await (await PresentationFile.exportPptx(p)).save(TMP+'/draft.pptx');
const result=await finalizePresentation({workspaceDir:ROOT,candidatePath:TMP+'/draft.pptx',finalPath:ROOT+'/output/Inbbi_중간발표_2026-10-31.pptx',pythonExecutable:'/Users/dohyun/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3',integrityValidatorPath:SKILL+'/container_tools/inspect_presentation_package_integrity.py',layoutValidatorPath:SKILL+'/container_tools/inspect_presentation_layout_geometry.py',layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry','--validate-heading-fit','--require-native-table-slide','3'],explicitTotalSlideCount:10,requiredNativeTableOwnerSlides:[3],fontPolicy:{basis:'design',families:[font]},verifyArtifactToolImport:true,receiptPath:TMP+'/validation.json'});
console.log(JSON.stringify(result));
