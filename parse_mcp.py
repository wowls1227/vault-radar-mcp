"""test-mcp.sh 가 받은 MCP 응답(JSON-RPC, 줄 단위)을 읽기 쉽게 출력합니다."""
import json
import sys

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    msg = json.loads(line)
    mid, res = msg.get("id"), msg.get("result")
    if "error" in msg:
        print(f"[id={mid}] 오류: {msg['error']}")
    elif mid == 1:
        info = res["serverInfo"]
        print(f"[1] 서버: {info['name']} {info.get('version', '')} / 프로토콜 {res['protocolVersion']}")
    elif mid == 2:
        names = sorted(t["name"] for t in res["tools"])
        print(f"[2] 도구 {len(names)}개")
        if "-v" in sys.argv:
            for n in names:
                print("    -", n)
    elif mid == 3:
        text = "".join(c.get("text", "") for c in res.get("content", []))
        flag = " (도구 오류)" if res.get("isError") else ""
        print(f"[3] 도구 호출 결과{flag}:")
        print(text[:1500])
