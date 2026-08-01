#!/bin/bash
# extension/deploy.sh: build, then deploy the output to the MarkEdit scripts directory
set -euo pipefail
cd "$(dirname "$0")"

CONTAINER="$HOME/Library/Containers/app.cyan.markedit/Data/Documents"
DEST="$CONTAINER/scripts"

# Check that MarkEdit is installed and initialized (gives a clear diagnostic instead of an opaque cp failure)
if [ ! -d "$CONTAINER" ]; then
  echo "error: MarkEdit이 설치·초기화되지 않았습니다 ($CONTAINER 없음)." >&2
  echo "       MarkEdit을 한 번 실행해 컨테이너를 생성한 뒤 다시 시도하세요." >&2
  exit 1
fi

# Always build from the latest source (avoids deploying a stale artifact)
npm run build

mkdir -p "$DEST"
cp dist/sticky-cast.js "$DEST/"
echo "deployed → $DEST/sticky-cast.js (MarkEdit 재시작 필요)"
