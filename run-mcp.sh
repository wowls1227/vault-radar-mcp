#!/usr/bin/env bash
# Vault Radar MCP 서버 실행 스크립트 (stdio, Docker)
# MCP 클라이언트(Claude Code, Cursor)가 이 스크립트를 실행합니다.
# stdout은 MCP 프로토콜 전용이므로 진단 메시지는 모두 stderr로 출력합니다.
set -euo pipefail

IMAGE="${VAULT_RADAR_MCP_IMAGE:-hashicorp/vault-radar-mcp-server:1.0.0}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$DIR/.env"

# GUI 앱에서 실행될 때 PATH가 짧을 수 있어 보강
export PATH="/opt/homebrew/bin:/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:$PATH"

err() { echo "[vault-radar-mcp] $*" >&2; }

if [[ ! -f "$ENV_FILE" ]]; then
  err ".env 파일이 없습니다: cp .env.example .env 후 값을 입력하세요."
  exit 1
fi

perm="$(stat -f '%Lp' "$ENV_FILE")"
if [[ "$perm" != "600" ]]; then
  err "경고: .env 권한이 $perm 입니다. chmod 600 .env 를 권장합니다."
fi

# .env 읽기 ("export KEY=값", "KEY=값" 모두 지원)
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

for v in HCP_PROJECT_ID HCP_CLIENT_ID HCP_CLIENT_SECRET; do
  if [[ -z "${!v:-}" ]]; then
    err "$v 가 비어 있습니다 (.env 확인)."
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  err "Docker 데몬에 연결할 수 없습니다. Docker Desktop을 실행하세요."
  exit 1
fi

# -e NAME (값 없이) → 현재 환경의 값을 전달. 명령줄(ps)에 시크릿이 노출되지 않음
exec docker run -i --rm \
  --name "vault-radar-mcp-$$" \
  -e HCP_PROJECT_ID \
  -e HCP_CLIENT_ID \
  -e HCP_CLIENT_SECRET \
  --read-only \
  --tmpfs /.config:rw,size=1m \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  "$IMAGE"
