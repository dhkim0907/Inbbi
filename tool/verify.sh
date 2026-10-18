#!/usr/bin/env bash
# 저장소 루트 밖에서도 실행할 수 있는 공통 검증 진입점.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

usage() {
  cat <<'EOF'
사용법: bash tool/verify.sh [all|calendar|notices|notifications|auth|settings|push-server]

기본값 all: Dart 서식 확인, Flutter 정적 분석, 전체 Flutter 테스트
기능 선택: 전체 Dart 서식 확인·정적 분석 후 해당 기능 테스트
push-server: 실제 전송 없이 Python 푸시 서버 테스트 (별도 의존성 필요)

서식을 자동 수정하거나 실제 계정에 연결하지 않습니다.
EOF
}

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

target="${1:-all}"
case "$target" in
  -h|--help) usage; exit 0 ;;
  all) test_paths=(test) ;;
  calendar) test_paths=(test/features/calendar test/core/widgets/calendar_week_event_bars_test.dart) ;;
  notices) test_paths=(test/features/notice_feed) ;;
  notifications) test_paths=(test/features/notification) ;;
  auth) test_paths=(test/features/auth) ;;
  settings) test_paths=(test/features/settings) ;;
  push-server)
    python3 -m unittest discover -s tool/push_server -p 'test_*.py' -v
    exit 0
    ;;
  *) usage >&2; exit 2 ;;
esac

for executable in flutter dart; do
  if ! command -v "$executable" >/dev/null 2>&1; then
    echo "필수 명령을 찾을 수 없습니다: $executable" >&2
    exit 127
  fi
done

echo '== Dart 서식 확인 =='
dart format --output=none --set-exit-if-changed lib test
echo '== Flutter 정적 분석 =='
flutter analyze --no-pub
echo "== Flutter 테스트: $target =="
flutter test --no-pub "${test_paths[@]}"
echo '검증을 통과했습니다.'
