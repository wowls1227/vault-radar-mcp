#!/usr/bin/env bash
# Vault Radar Agent 관리 (Docker, 백그라운드 상시 실행)
#   ./agent.sh start   : 에이전트 시작 (Docker 재시작 시 자동 기동)
#   ./agent.sh stop    : 중지·삭제
#   ./agent.sh restart : 재시작 (.env.agent 변경 후)
#   ./agent.sh status  : 상태
#   ./agent.sh logs    : 로그 따라보기
set -euo pipefail

IMAGE="${VAULT_RADAR_IMAGE:-hashicorp/vault-radar:0.55.1}"
NAME="vault-radar-agent"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${AGENT_ENV_FILE:-$DIR/.env.agent}"
export PATH="/opt/homebrew/bin:/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:$PATH"

err() { echo "[vault-radar-agent] $*" >&2; }

start() {
  [[ -f "$ENV_FILE" ]] || { err "$ENV_FILE 이 없습니다: cp .env.agent.example .env.agent"; exit 1; }
  [[ "$(stat -f '%Lp' "$ENV_FILE")" == "600" ]] || err "경고: $ENV_FILE 권한을 600 으로 설정하세요."
  set -a; source "$ENV_FILE"; set +a
  for v in HCP_PROJECT_ID HCP_CLIENT_ID HCP_CLIENT_SECRET HCP_RADAR_AGENT_POOL_ID; do
    [[ -n "${!v:-}" ]] || { err "$v 가 비어 있습니다."; exit 1; }
  done
  docker info >/dev/null 2>&1 || { err "Docker Desktop을 실행하세요."; exit 1; }
  docker rm -f "$NAME" >/dev/null 2>&1 || true

  # .env.agent 에 있는 변수 이름만 -e 로 전달 (값은 명령줄에 노출되지 않음)
  envs=()
  while IFS= read -r k; do envs+=(-e "$k"); done < <(
    sed -nE 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=.*/\2/p' "$ENV_FILE" | sort -u)

  docker run -d --name "$NAME" --restart unless-stopped \
    "${envs[@]}" \
    --cap-drop ALL --security-opt no-new-privileges \
    "$IMAGE" vault-radar agent exec >/dev/null
  echo "시작됨: $NAME ($IMAGE). 로그: ./agent.sh logs"
}

case "${1:-status}" in
  start)   start ;;
  stop)    docker rm -f "$NAME" >/dev/null && echo "중지됨" ;;
  restart) start ;;
  status)  docker ps -a --filter "name=^${NAME}$" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' ;;
  logs)    docker logs -f --tail 50 "$NAME" ;;
  *) err "사용법: $0 {start|stop|restart|status|logs}"; exit 1 ;;
esac
