#!/usr/bin/env bash
# 탐지 검증용 테스트 저장소 생성 (가짜 시크릿, 실행할 때마다 무작위 생성)
#   ./scripts/make-leak-test-repo.sh [경로]   (기본: ./leak-test-repo)
# 생성되는 값은 형식만 실제 시크릿과 같고 어떤 서비스에서도 유효하지 않습니다.
set -euo pipefail
DEST="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/leak-test-repo}"
[[ -e "$DEST" ]] && { echo "이미 존재합니다: $DEST" >&2; exit 1; }
mkdir -p "$DEST"/{config,src,deploy,scripts}
cd "$DEST"

python3 -I - <<'PY'
import secrets, string
A = string.ascii_letters + string.digits
U = string.ascii_uppercase + string.digits
r = lambda n, c=A: "".join(secrets.choice(c) for _ in range(n))

open("README.md", "w").write("""# leak-test-repo

> ⚠️ Vault Radar 탐지 검증용 테스트 저장소입니다.
> 모든 키·비밀번호는 무작위로 생성한 가짜 값이며 어떤 서비스에서도 유효하지 않습니다.
""")
open("config/aws.ini", "w").write(
    f"[default]\naws_access_key_id = AKIA{r(16, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567')}\n"
    f"aws_secret_access_key = {r(40, A + '/+')}\nregion = ap-northeast-2\n")
pw = r(20)
open("config/app.yaml", "w").write(f"""app:
  name: leak-test
database:
  host: db.internal.example.com
  port: 5432
  user: app_admin
  password: "{pw}"
  url: "postgresql://app_admin:{pw}@db.internal.example.com:5432/orders"
""")
open("src/db.py", "w").write(f'''import psycopg2

# TODO: 환경변수로 옮길 것 (테스트용 하드코딩)
DSN = "postgresql://svc_report:{r(18)}@10.10.20.5:5432/report"

def connect():
    return psycopg2.connect(DSN)
''')
open("src/notify.js", "w").write(f'''const SLACK_WEBHOOK = "https://hooks.slack.com/services/T{r(8, U)}/B{r(8, U)}/{r(24)}";

async function notify(msg) {{
  await fetch(SLACK_WEBHOOK, {{ method: "POST", body: JSON.stringify({{ text: msg }}) }});
}}
module.exports = {{ notify }};
''')
open("deploy/.env.production", "w").write(f"""STRIPE_SECRET_KEY=sk_live_{r(24)}
SENDGRID_API_KEY=SG.{r(22)}.{r(43)}
JWT_SIGNING_SECRET={r(48)}
REDIS_URL=redis://:{r(24)}@cache.internal.example.com:6379/0
""")
PY
openssl genrsa -traditional -out scripts/deploy_key.pem 2048 2>/dev/null \
  || openssl genrsa -out scripts/deploy_key.pem 2048 2>/dev/null

git init -q -b main
git add -A && git commit -q -m "Add test config (fake secrets for Vault Radar verification)"
# 이력에만 남는 시크릿 (파일 삭제 후에도 git 이력에 존재)
python3 -I -c "import secrets,string;A=string.ascii_letters+string.digits;open('scripts/ci_token.txt','w').write('GITLAB_TOKEN=glpat-'+''.join(secrets.choice(A) for _ in range(20))+'\n')"
git add -A && git commit -q -m "Add CI token"
git rm -q scripts/ci_token.txt && git commit -q -m "Remove CI token (still in history)"

echo "생성됨: $DEST"
git log --oneline
