"""Ollama-style local HTTP API server.

Endpoints:
  GET  /api/tags
  POST /api/show
  POST /api/generate
  POST /api/chat

Single-threaded, blocking, sufficient for local use.
Streams NDJSON for /api/generate and /api/chat when "stream": true (default).
"""

from __future__ import annotations

import json
import socket
import threading
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Optional

from ..engine.llm_engine import LlamaEngine, SamplingParams
from ..storage.model_manager import ModelManager


class _Handler(BaseHTTPRequestHandler):
    server_version = "Neth-AI/0.1"
    engine: LlamaEngine = None  # type: ignore
    model_manager: ModelManager = None  # type: ignore
    log_widget = None

    def log_message(self, fmt, *args):
        try:
            if _Handler.log_widget is not None:
                msg = fmt % args
                _Handler.log_widget.append(f"[{datetime.utcnow().isoformat()}Z] {msg}")
        except Exception:
            pass

    def _send_json(self, status: int, obj: dict) -> None:
        body = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode("utf-8")) if raw else {}
        except Exception:
            return {}

    def do_GET(self):
        if self.path == "/api/tags":
            self._tags()
        elif self.path in ("/", "/api"):
            self._send_json(200, {"name": "Neth-AI", "version": "0.1.0"})
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self):
        if self.path == "/api/show":
            self._send_json(200, {"info": "ok"})
        elif self.path == "/api/generate":
            self._generate()
        elif self.path == "/api/chat":
            self._chat()
        else:
            self._send_json(404, {"error": "not found"})

    def _tags(self):
        models = _Handler.model_manager.list_installed()
        out = {"models": []}
        for m in models:
            out["models"].append({
                "name": m.file_name,
                "size": m.file_size,
                "quant": m.quantization,
                "params": m.parameter_count,
                "vision": m.supports_vision,
            })
        self._send_json(200, out)

    def _generate(self):
        body = self._read_body()
        prompt = body.get("prompt", "")
        stream = body.get("stream", True)
        if not prompt:
            self._send_json(400, {"error": "missing prompt"})
            return
        if not _Handler.engine.is_loaded:
            self._send_json(400, {"error": "no model loaded"})
            return

        params = SamplingParams(
            temperature=body.get("temperature", 0.7),
            top_p=body.get("top_p", 0.9),
            top_k=body.get("top_k", 40),
            max_tokens=body.get("num_predict", 512),
            repeat_penalty=body.get("repeat_penalty", 1.1),
        )

        if stream:
            self.send_response(200)
            self.send_header("Content-Type", "application/x-ndjson")
            self.send_header("Connection", "close")
            self.end_headers()
            stats = None
            try:
                for tok in _Handler.engine.generate(prompt, params):
                    if tok.is_final:
                        stats = tok.stats
                        continue
                    if tok.text:
                        chunk = {
                            "model": _Handler.engine.loaded_model_name,
                            "response": tok.text,
                            "done": False,
                        }
                        self.wfile.write((json.dumps(chunk) + "\n").encode("utf-8"))
                        self.wfile.flush()
                final = {
                    "model": _Handler.engine.loaded_model_name,
                    "response": "",
                    "done": True,
                    "stats": {
                        "tokens_per_second": stats.tokens_per_second if stats else 0,
                        "time_to_first_token": stats.time_to_first_token if stats else 0,
                        "total_tokens": stats.total_tokens if stats else 0,
                    } if stats else None,
                }
                self.wfile.write((json.dumps(final) + "\n").encode("utf-8"))
                self.wfile.flush()
            except Exception as e:
                err = {"error": str(e)}
                self.wfile.write((json.dumps(err) + "\n").encode("utf-8"))
        else:
            full = ""
            stats = None
            try:
                for tok in _Handler.engine.generate(prompt, params):
                    if tok.is_final:
                        stats = tok.stats
                    else:
                        full += tok.text
            except Exception as e:
                self._send_json(500, {"error": str(e)})
                return
            self._send_json(200, {
                "model": _Handler.engine.loaded_model_name,
                "response": full,
                "done": True,
                "stats": {
                    "tokens_per_second": stats.tokens_per_second if stats else 0,
                    "time_to_first_token": stats.time_to_first_token if stats else 0,
                    "total_tokens": stats.total_tokens if stats else 0,
                } if stats else None,
            })

    def _chat(self):
        body = self._read_body()
        messages = body.get("messages", [])
        stream = body.get("stream", True)
        if not messages:
            self._send_json(400, {"error": "missing messages"})
            return
        if not _Handler.engine.is_loaded:
            self._send_json(400, {"error": "no model loaded"})
            return

        prompt = ""
        for m in messages:
            role = m.get("role", "user")
            content = m.get("content", "")
            prompt += f"<|im_start|>{role}\n{content}<|im_end|>\n"
        prompt += "<|im_start|>assistant\n"

        params = SamplingParams(
            temperature=body.get("temperature", 0.7),
            top_p=body.get("top_p", 0.9),
            top_k=body.get("top_k", 40),
            max_tokens=body.get("num_predict", 512),
            repeat_penalty=body.get("repeat_penalty", 1.1),
        )

        if stream:
            self.send_response(200)
            self.send_header("Content-Type", "application/x-ndjson")
            self.send_header("Connection", "close")
            self.end_headers()
            stats = None
            try:
                for tok in _Handler.engine.generate(prompt, params):
                    if tok.is_final:
                        stats = tok.stats
                        continue
                    if tok.text:
                        chunk = {
                            "model": _Handler.engine.loaded_model_name,
                            "message": {"role": "assistant", "content": tok.text},
                            "done": False,
                        }
                        self.wfile.write((json.dumps(chunk) + "\n").encode("utf-8"))
                        self.wfile.flush()
                final = {
                    "model": _Handler.engine.loaded_model_name,
                    "message": {"role": "assistant", "content": ""},
                    "done": True,
                    "stats": {
                        "tokens_per_second": stats.tokens_per_second if stats else 0,
                        "time_to_first_token": stats.time_to_first_token if stats else 0,
                        "total_tokens": stats.total_tokens if stats else 0,
                    } if stats else None,
                }
                self.wfile.write((json.dumps(final) + "\n").encode("utf-8"))
                self.wfile.flush()
            except Exception as e:
                err = {"error": str(e)}
                self.wfile.write((json.dumps(err) + "\n").encode("utf-8"))
        else:
            full = ""
            stats = None
            try:
                for tok in _Handler.engine.generate(prompt, params):
                    if tok.is_final:
                        stats = tok.stats
                    else:
                        full += tok.text
            except Exception as e:
                self._send_json(500, {"error": str(e)})
                return
            self._send_json(200, {
                "model": _Handler.engine.loaded_model_name,
                "message": {"role": "assistant", "content": full},
                "done": True,
            })


class APIServer:
    _server: Optional[ThreadingHTTPServer] = None
    _thread: Optional[threading.Thread] = None

    @classmethod
    def start(cls, host: str = "127.0.0.1", port: int = 11434, log=None) -> bool:
        if cls._server is not None:
            return True
        _Handler.engine = LlamaEngine._instance if hasattr(LlamaEngine, "_instance") else None
        # bind a shared engine reference
        from ..app_state import AppState
        _Handler.engine = AppState.instance().engine
        _Handler.model_manager = AppState.instance().model_manager
        _Handler.log_widget = log
        try:
            srv = ThreadingHTTPServer((host, port), _Handler)
            srv.daemon_threads = True
        except OSError:
            return False
        cls._server = srv
        cls._thread = threading.Thread(target=srv.serve_forever, daemon=True)
        cls._thread.start()
        return True

    @classmethod
    def stop(cls) -> None:
        if cls._server is not None:
            cls._server.shutdown()
            cls._server.server_close()
            cls._server = None
            cls._thread = None
