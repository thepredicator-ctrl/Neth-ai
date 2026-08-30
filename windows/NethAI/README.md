# Neth-AI for Windows

Real local LLM assistant for Windows. Black + glowing-orange Neth-AI identity, Neth Orb animation, GGUF model management, streaming generation, Ollama-style local API, optional PC server mode.

## Run from source

```powershell
cd windows\NethAI
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
# Install llama-cpp-python with CUDA (optional, for GPU acceleration):
# $env:CMAKE_ARGS="-DGGML_CUDA=on"; pip install llama-cpp-python --upgrade --force-reinstall --no-cache-dir
python -m neth_ai
```

## Build the .exe

```powershell
pip install pyinstaller
pyinstaller build.spec
# Output: dist/Neth-AI-Windows-x64.exe
```

## Local API (Ollama-style)

When enabled in Settings, Neth-AI exposes:

- `GET  /api/tags`
- `POST /api/show`
- `POST /api/generate`
- `POST /api/chat`

Listening on `127.0.0.1:11434` by default. For PC server mode, switch to `0.0.0.0` and connect your iPad over local Wi-Fi.

## PC Server Mode

Settings → "Expose on local network" → restart. The iPad app can connect via `http://<PC-IP>:11434`.

## Model support

GGUF format only. Tested with Qwen2, Llama 3, Phi-3, Mistral, Gemma GGUFs (Q4_K_M recommended).
