#!/bin/bash
# extension/deploy.sh — 빌드 후 산출물을 MarkEdit scripts 디렉토리로 배포
set -euo pipefail
cd "$(dirname "$0")"

CONTAINER="$HOME/Library/Containers/app.cyan.markedit/Data/Documents"
DEST="$CONTAINER/scripts"

# MarkEdit 설치·초기화 확인 (미설치 시 불투명한 cp 실패 대신 명확한 진단)
if [ ! -d "$CONTAINER" ]; then
  echo "error: MarkEdit이 설치·초기화되지 않았습니다 ($CONTAINER 없음)." >&2
  echo "       MarkEdit을 한 번 실행해 컨테이너를 생성한 뒤 다시 시도하세요." >&2
  exit 1
fi

# 항상 최신 소스로 빌드 (stale 산출물 배포 방지)
npm run build

mkdir -p "$DEST"
cp dist/sticky-cast.js "$DEST/"
echo "deployed → $DEST/sticky-cast.js (MarkEdit 재시작 필요)"
