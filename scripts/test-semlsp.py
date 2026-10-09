#!/usr/bin/env python3
"""Stdio LSP integration smoke test; run after `swift build --product semlsp`."""
import json
import select
import subprocess
import sys
from pathlib import Path


def packet(message):
    body = json.dumps(message).encode()
    return f"Content-Length: {len(body)}\r\n\r\n".encode() + body


def recv(pipe, timeout=15):
    fd = pipe.fileno()

    def one():
        if not select.select([fd], [], [], timeout)[0]:
            raise TimeoutError("Timed out waiting for semlsp response")
        return pipe.read(1)

    header = b""
    while not header.endswith(b"\r\n\r\n"):
        byte = one()
        assert byte, "semlsp closed stdout unexpectedly"
        header += byte
    length = None
    for line in header.split(b"\r\n"):
        if line.lower().startswith(b"content-length:"):
            length = int(line.split(b":", 1)[1])
    assert length is not None
    body = b""
    while len(body) < length:
        if not select.select([fd], [], [], timeout)[0]:
            raise TimeoutError("Timed out waiting for semlsp message body")
        chunk = pipe.read(length - len(body))
        assert chunk, "semlsp closed stdout while sending a packet"
        body += chunk
    return json.loads(body)


def send(process, message):
    process.stdin.write(packet({"jsonrpc": "2.0", **message}))
    process.stdin.flush()


def expect(process, method):
    while True:
        result = recv(process.stdout)
        if result.get("method") == method:
            return result


def main(binary):
    process = subprocess.Popen([binary], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               bufsize=0)
    try:
        send(process, {"id": 1, "method": "initialize", "params": {
            "processId": None, "capabilities": {}
        }})
        response = recv(process.stdout)
        assert response.get("id") == 1, response
        assert response["result"]["capabilities"]["positionEncoding"] == "utf-16"
        send(process, {"method": "initialized", "params": {}})

        uri = "file:///tmp/semlsp-smoke.swift"
        send(process, {"method": "textDocument/didOpen", "params": {
            "textDocument": {"uri": uri, "languageId": "swift", "version": 1,
                             "text": 'let greeting = "🐕"\n'}
        }})
        opened = expect(process, "textDocument/publishDiagnostics")["params"]
        assert opened["version"] == 1
        assert any(d.get("code") == "no_emoji" for d in opened["diagnostics"]), opened

        send(process, {"method": "textDocument/didChange", "params": {
            "textDocument": {"uri": uri, "version": 2},
            "contentChanges": [{"text": 'let greeting = "hello"\n'}]
        }})
        changed = expect(process, "textDocument/publishDiagnostics")["params"]
        assert changed["version"] == 2
        assert not any(d.get("code") == "no_emoji" for d in changed["diagnostics"])

        send(process, {"method": "textDocument/didClose", "params": {
            "textDocument": {"uri": uri}
        }})
        closed = expect(process, "textDocument/publishDiagnostics")["params"]
        assert closed["diagnostics"] == []

        send(process, {"id": 3, "method": "shutdown", "params": None})
        answer = recv(process.stdout)
        assert answer.get("id") == 3 and answer["result"] is None
        send(process, {"method": "exit", "params": None})
        process.stdin.close()
        assert process.wait(timeout=5) == 0
        print("PASS: initialize, unsaved text, diagnostics, change, close, shutdown")
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else ".build/debug/semlsp"
    main(str(Path(target).resolve()))
