# Vault Radar MCP

HCP Vault Radar로 **유출된 시크릿을 탐지**하고, 그 결과를 **Claude Code·Cursor 같은 AI 도구에서 자연어로 조회**할 수 있게 구성한 로컬 실행 키트입니다.

```
[폴더 / Git 저장소 / 협업 도구]
        │ ① 스캔 (로컬 Agent·CLI, 코드는 외부로 나가지 않음)
        ▼
[HCP Vault Radar]  ← 탐지 결과 저장 (시크릿 원문은 저장하지 않음)
        │ ② 조회 전용 API (Viewer 권한)
        ▼
[Vault Radar MCP 서버 (Docker, stdio)]
        │ ③ MCP
        ▼
[Claude Code / Cursor]  "위험도 높은 유출 시크릿을 위치와 함께 정리해 줘"
```

| 구성 요소 | 역할 | 실행 |
|---|---|---|
| MCP 서버 (`hashicorp/vault-radar-mcp-server`) | AI가 탐지 결과를 **조회만** 하도록 연결 | `run-mcp.sh` (클라이언트가 자동 실행) |
| Agent (`hashicorp/vault-radar`) | Git 저장소 등을 로컬에서 상시 스캔 | `agent.sh` |
| CLI (`hashicorp/vault-radar`) | 폴더·저장소를 즉석 스캔 | `scan-local.sh` |

> MCP 서버는 탐지를 하지 않습니다. 탐지는 Agent·CLI·HCP가 하고, MCP 서버는 결과를 읽기만 합니다.

---

## 사전 준비

- **Docker Desktop**: 실행 중이어야 함
- **Python 3**: 점검 스크립트용
- **HCP 계정**과 Vault Radar가 활성화된 프로젝트
- **서비스 주체**: 프로젝트 → Access control (IAM) → Service principals에서 용도별로 생성하고 키 발급

| 용도 | 역할 | 설정 파일 | 필수 |
|---|---|---|---|
| MCP 서버 | Viewer | `.env` | ✅ |
| Agent | Vault Radar Agent | `.env.agent` | Agent를 쓸 때 |
| 로컬 CLI 스캔 | Vault Radar CLI User | `.env.cli` | CLI를 쓸 때 |

- **Agent pool ID** (Agent를 쓸 때): Vault Radar → Settings → Agent → Add an agent pool

---

## 빠른 시작

```bash
git clone https://github.com/wowls1227/vault-radar-mcp.git
cd vault-radar-mcp
./setup.sh
```

`setup.sh`는 `.env`, `.env.agent`, `.env.cli`를 예시 파일에서 만들고(권한 600), 현재 경로로 MCP 설정 파일(`.mcp.json`, `.cursor/mcp.json`)을 생성합니다.

### 1. 키 입력

편집기로 `.env`에 값을 입력합니다. **키를 채팅·메신저에 붙여 넣지 마세요.**

```bash
export HCP_PROJECT_ID=<프로젝트 ID>
export HCP_CLIENT_ID=<Viewer 서비스 주체 Client ID>
export HCP_CLIENT_SECRET=<Viewer 서비스 주체 Client Secret>
```

### 2. MCP 서버 점검

```bash
docker pull hashicorp/vault-radar-mcp-server:1.0.0
VERBOSE=1 ./test-mcp.sh                                  # 서버 기동, 도구 4개 확인
./test-mcp.sh call query_vault_radar_events '{}'         # HCP 연동 확인
```

### 3. AI 도구에 연결

- **Claude Code**: 이 폴더에서 새 대화를 열고 `/mcp`를 입력해 `vault-radar`를 승인합니다.
- **Cursor**: Settings → MCP에서 `vault-radar`를 켭니다.

### 4. 질문하기

```
Vault Radar에 연결된 데이터 소스 알려줘
탐지된 이벤트를 위험도별로 분류해서 목록으로 만들어줘
위 목록을 시크릿 유형별로 다시 구분해줘
각 이벤트가 있는 파일 위치를 함께 넣어서 정리해줘
git 이력에만 남아 있는 시크릿이 있어?
```

| MCP 도구 | 하는 일 |
|---|---|
| `query_vault_radar_data_sources` | 스캔 대상(데이터 소스) 조회 |
| `query_vault_radar_resources` | 리소스(저장소·폴더 등)와 심각도별 건수 조회 |
| `query_vault_radar_events` | 탐지 이벤트(위치·유형·심각도) 조회 |
| `list_vault_radar_secret_types` | 탐지된 시크릿 유형 조회 |

---

## 스캔하기

### 폴더 스캔 (CLI)

`.env.cli`에 CLI User 역할 키를 넣은 뒤 실행합니다.

```bash
./scan-local.sh folder ~/Projects          # 현재 파일 (압축 파일 내부 포함)
./scan-local.sh repo   ./some-git-repo      # git 커밋 이력 포함
```

- 결과는 `scan-results/<이름>-<시각>.json`에 저장되고 HCP에도 올라가서 MCP로 조회할 수 있습니다.
- 결과 파일에는 시크릿 원문이 없고 해시만 있습니다.

### 상시 스캔 (Agent)

`.env.agent`에 Agent 역할 키와 pool ID를 넣고 실행합니다.

```bash
./agent.sh start      # 백그라운드 실행 (Docker가 다시 시작되면 자동 기동)
./agent.sh status
./agent.sh logs
```

GitHub 저장소를 스캔하려면 다음 두 가지를 합니다.

1. `.env.agent`에 `VAULT_RADAR_GIT_TOKEN`(읽기 전용 PAT)을 추가하고 `./agent.sh restart`를 실행합니다.
2. HCP 포털 → Settings → Data Sources → **agent scan**에서 토큰을 `env://VAULT_RADAR_GIT_TOKEN`으로 등록합니다.

### 탐지 테스트

가짜 시크릿 12종이 든 테스트 저장소를 만들어 탐지 여부를 확인합니다. 값은 실행할 때마다 무작위로 생성되며 유효하지 않습니다.

```bash
./scripts/make-leak-test-repo.sh
./scan-local.sh folder ./leak-test-repo
```

---

## 파일 구성

| 파일 | 설명 |
|---|---|
| `setup.sh` | 초기 설정 (`.env*` 생성·권한, MCP 설정 생성) |
| `run-mcp.sh` | MCP 서버 실행 (Docker, stdio, 읽기 전용 컨테이너) |
| `test-mcp.sh`, `parse_mcp.py` | MCP 연결·도구 호출 점검 |
| `agent.sh` | Agent start / stop / restart / status / logs |
| `scan-local.sh` | CLI 폴더·저장소 스캔 |
| `scripts/make-leak-test-repo.sh` | 탐지 검증용 테스트 저장소 생성 |
| `.env*.example` | 환경변수 템플릿 |
| `.mcp.json.example`, `.cursor/mcp.json.example` | MCP 클라이언트 설정 템플릿 |
| [구축가이드.md](구축가이드.md) | 상세 구축 방법, 문제 해결, 보안 수칙 |
| [탐지검증_절차서.md](탐지검증_절차서.md) | 단계별 탐지 검증 절차와 결과 예시 |

---

## 보안

- **키 분리**: MCP(Viewer), Agent, CLI 키를 따로 발급합니다.
- **키 보관**: `.env*`는 권한 600이고 `.gitignore`로 제외됩니다. 스크립트는 `docker run -e 이름`으로 값을 전달해 명령줄(`ps`)에 시크릿이 보이지 않습니다.
- **원문 없음**: Vault Radar와 MCP 응답에는 시크릿 원문이 없습니다.
- **메타데이터는 전달됨**: 파일 경로, 폴더명, PC 이름, 시크릿 유형은 HCP에 올라가고 MCP를 통해 AI에도 전달됩니다. 외부 LLM을 쓸 때는 사내 기준을 확인하세요.
- **커밋 제외 대상**: `scan-results/`, `leak-test-repo/`, `.mcp.json`(로컬 경로 포함)은 git에 올리지 않습니다.
- **탐지 한계**: 정해진 형식이 없는 시크릿(예: HCP 서비스 주체 키)은 탐지되지 않을 수 있습니다.

---

## 참고

- [Vault Radar MCP server](https://developer.hashicorp.com/hcp/docs/vault-radar/mcp-server/deploy)
- [Vault Radar agent](https://developer.hashicorp.com/hcp/docs/vault-radar/agent/deploy)
- [Vault Radar CLI](https://developer.hashicorp.com/hcp/docs/vault-radar/cli)
- [Vault Radar security model](https://developer.hashicorp.com/hcp/docs/vault-radar/security-model)
