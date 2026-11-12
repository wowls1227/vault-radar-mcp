#!/usr/bin/env bash
# Vault Radar CLI 로컬 스캔 (Docker)
#   ./scan-local.sh repo   <git 저장소 경로>   : 커밋 이력 포함 스캔
#   ./scan-local.sh folder <폴더 경로>         : 현재 파일만 스캔
# 결과: scan-results/<이름>-<시각>.json  (HCP 프로젝트에도 스캔 기록이 남음)
set -euo pipefail

IMAGE="${VAULT_RADAR_IMAGE:-hashicorp/vault-radar:0.55.1}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${CLI_ENV_FILE:-$DIR/.env.cli}"
MODE="${1:-}"; TARGET="${2:-}"
export PATH="/opt/homebrew/bin:/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:$PATH"
err() { echo "[vault-radar-cli] $*" >&2; }

[[ "$MODE" == "repo" || "$MODE" == "folder" ]] && [[ -d "$TARGET" ]] || { err "사용법: $0 {repo|folder} <경로>"; exit 1; }
[[ -f "$ENV_FILE" ]] || { err "$ENV_FILE 이 없습니다: cp .env.cli.example .env.cli"; exit 1; }
set -a; source "$ENV_FILE"; set +a

TARGET="$(cd "$TARGET" && pwd)"
mkdir -p "$DIR/scan-results"
OUT="$(basename "$TARGET")-$(date +%Y%m%d-%H%M%S).json"

# 호스트와 같은 경로로 마운트해 결과 URI에 실제 경로가 남도록 함
HOST="${SCAN_HOST_NAME:-$(hostname -s)}"
if [[ "$MODE" == "repo" ]]; then
  CMD="git config --global --add safe.directory '$TARGET'; vault-radar scan repo -c '$TARGET'"
else
  CMD="vault-radar scan folder -p '$TARGET' --host-name '$HOST'"
fi

# --skip-activeness: 키가 실제로 유효한지 외부 서비스에 확인하지 않음 (테스트용 가짜 키)
docker run --rm \
  -e HCP_PROJECT_ID -e HCP_CLIENT_ID -e HCP_CLIENT_SECRET \
  -v "$TARGET:$TARGET:ro" -v "$DIR/scan-results:/out" \
  "$IMAGE" sh -c "$CMD -f json -o /out/$OUT --skip-activeness --disable-ui"

echo "결과: scan-results/$OUT"
python3 -I -c '
import json,sys,collections
p=sys.argv[1]; rows=[json.loads(l) for l in open(p) if l.strip()]
print(f"탐지 {len(rows)}건")
for k,v in collections.Counter(r.get("type") or r.get("category") or "?" for r in rows).most_common(): print(f"  {v:3d}  {k}")
' "$DIR/scan-results/$OUT" 2>/dev/null || true
