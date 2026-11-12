#!/usr/bin/env bash
# 초기 설정: 환경변수 파일 생성(권한 600), MCP 클라이언트 설정 파일 생성
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

for f in .env .env.agent .env.cli; do
  if [[ ! -f "$f" ]]; then
    cp "$f.example" "$f"
    echo "생성: $f  (값을 입력하세요)"
  fi
  chmod 600 "$f"
done

mkdir -p .cursor
sed "s|__PROJECT_DIR__|$DIR|g" .mcp.json.example > .mcp.json
sed "s|__PROJECT_DIR__|$DIR|g" .cursor/mcp.json.example > .cursor/mcp.json
echo "생성: .mcp.json, .cursor/mcp.json  (경로: $DIR)"
chmod +x run-mcp.sh test-mcp.sh agent.sh scan-local.sh scripts/*.sh
