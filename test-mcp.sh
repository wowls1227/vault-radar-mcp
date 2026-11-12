#!/usr/bin/env bash
# Vault Radar MCP 서버 연결 점검
#   ./test-mcp.sh                        : initialize + 도구 목록
#   VERBOSE=1 ./test-mcp.sh              : + 도구 이름 출력
#   ./test-mcp.sh call <도구> '<JSON 인자>' : + 도구 호출
#     예) ./test-mcp.sh call list_vault_radar_secret_types '{}'
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-basic}"
TOOL="${2:-}"
ARGS="${3:-{\}}"
WAIT="${WAIT:-10}"

requests() {
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test-mcp","version":"1.0"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  if [[ "$MODE" == "call" ]]; then
    printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$TOOL" "$ARGS"
  fi
  sleep "$WAIT"
}

requests | "$DIR/run-mcp.sh" 2>"${STDERR_LOG:-/dev/null}" | python3 -I "$DIR/parse_mcp.py" ${VERBOSE:+-v}
