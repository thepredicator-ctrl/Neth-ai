# Neth-AI

> A futuristic black + glowing-orange local AI assistant for iPadOS and Windows.
> The device is your iPad or PC — Neth-AI is the appliance that lives on it.

Neth-AI runs real GGUF LLMs **entirely locally** with on-device inference,
streaming generation, voice, vision, conversation history, and an Ollama-style
local API. It is built around a signature animated **Neth Orb** that reacts to
every application state — idle, listening, thinking, generating, complete, error.

Two real apps share one identity:

- **iOS / iPadOS** — SwiftUI + SwiftLlama (llama.cpp via Apple's official pre-built XCFramework)
- **Windows** — PySide6 (Qt 6) + llama-cpp-python

No cloud. No fake inference. No fabricated stats.

---

## Screenshots / Visual Identity

```
       .-~~~~-.
     .'        '.
    /   .----.   \      Deep black canvas
   |   /      \   |     Vivid glowing orange orb
   |  |   __   |  |     Amber highlights
    \  \ '.__.'/  /     Subtle white text
     '.________.'       Orange particles + rings + pulse
```

The orb is rendered with multi-layer Canvas (iOS) / QPainter (Windows):
halo, rotating energy rings, particle field, radial-gradient core, specular
highlight, inner waveform during listen/generate.

---

## Features

### Cross-platform identity

- Black + glowing-orange design system
- Signature animated Neth Orb with six reactive states
- Premium hardware-like feel; no ChatGPT blue, no corporate dashboard

### Real local inference

- GGUF model support
- llama.cpp engine (SwiftLlama wrapper on iOS, llama-cpp-python on Windows)
- Metal acceleration on Apple Silicon
- CUDA acceleration on Windows (when available)
- Streaming token generation
- Real measured performance: tok/s, TTFT, total tokens, memory, context size

### Assistant screen

- Neth Orb centered
- Voice input (on-device Speech framework on iOS, SpeechRecognition on Windows)
- Text input
- Current model chip
- Generation state label
- Stop button
- Live performance summary (e.g. `14.2 tok/s  -  1.7s TTFT`)

### Conversations

- New / rename / delete / search
- Per-conversation model name
- Timestamps
- Stored locally (JSON on iOS, JSON in `~/.neth-ai` on Windows)
- Elegant non-bubble response presentation

### Model manager

- Import GGUF files via Files (iOS) or file dialog (Windows)
- Detects quantization, parameter count, vision capability from filename
- Storage usage display
- Load / unload / switch models
- Delete with confirmation
- Handles invalid GGUF, duplicates, insufficient storage

### Voice

- Native speech recognition (on-device where available)
- Proper microphone permission handling
- Mic button toggles listening state on the Neth Orb

### Vision (where supported)

- Camera capture (iOS)
- Photos picker
- Image attachment preview
- Only displayed for models detected as vision-capable; never lies about vision support

### Performance panel

- tok/s
- Time to first token (TTFT)
- Context size
- Memory usage
- Metal/CUDA acceleration indicator

### Local API (Ollama-style)

Optional HTTP server with:

| Endpoint | Method | Description |
|---|---|---|
| `/api/tags` | GET | List installed models |
| `/api/show` | POST | Show model info |
| `/api/generate` | POST | Streaming text generation (NDJSON) |
| `/api/chat` | POST | Streaming chat (NDJSON) |

Default bind: `127.0.0.1:11434` — never exposed publicly.

### PC Server Mode (optional)

The Windows app can act as a local AI server. The iPad app can connect over
your local Wi-Fi:

```
   iPad
     │
  Local Wi-Fi
     │
     ▼
Neth-AI PC Server  ──▶  GPU inference  ──▶  LLM
```

Enable in Tools → "Expose on local network", then point your iPad's Neth-AI
Settings → PC Server Mode at the PC's IP.

The iPad retains independent local inference capability.

---

## Architecture

```
Neth-ai/
├── ios/
│   └── NethAI/                       # Xcode project (XcodeGen)
│       ├── project.yml               # XcodeGen spec
│       └── NethAI/
│           ├── NethAIApp.swift
│           ├── App/                  # AppState, RootView
│           ├── Theme/                # NethTheme (colors, fonts, glow)
│           ├── Engine/               # LLMEngine protocol + LlamaEngine
│           ├── Components/           # NethOrbView (Canvas + TimelineView)
│           ├── Features/
│           │   ├── Assistant/
│           │   ├── Conversations/
│           │   ├── Models/
│           │   └── Settings/
│           ├── Models/               # Conversation, InstalledModel
│           ├── Storage/              # ConversationStore, ModelManager
│           ├── Voice/                # SpeechRecognizer (SFSpeechRecognizer)
│           ├── Vision/               # ImageInputManager + PhotosPicker
│           ├── API/                  # LocalAPIServer (Network.framework)
│           └── Resources/            # Assets.xcassets, Info.plist
├── windows/
│   └── NethAI/
│       ├── neth_ai/
│       │   ├── main.py               # MainWindow + sidebar nav
│       │   ├── app_state.py
│       │   ├── engine/               # LlamaEngine (llama-cpp-python)
│       │   ├── ui/
│       │   │   ├── theme.py          # NethTheme palette + QSS
│       │   │   ├── orb_widget.py     # NethOrbWidget (QPainter + QTimer)
│       │   │   ├── assistant_view.py
│       │   │   ├── conversations_view.py
│       │   │   ├── models_view.py
│       │   │   ├── tools_view.py
│       │   │   └── settings_view.py
│       │   ├── models/
│       │   ├── storage/
│       │   ├── api/                  # APIServer (ThreadingHTTPServer)
│       │   └── voice/
│       ├── build.spec                # PyInstaller
│       ├── requirements.txt
│       └── resources/neth.ico
├── shared/                           # cross-platform notes
├── docs/
├── .github/workflows/
│   ├── build-ios.yml
│   ├── build-windows.yml
│   └── release.yml
├── README.md
└── LICENSE
```

---

## Supported Platforms

| Platform | Min version | Engine | Acceleration |
|---|---|---|---|
| iPadOS / iOS | 17.0 | SwiftLlama (llama.cpp XCFramework) | Metal |
| Windows | 10 / 11 x64 | llama-cpp-python | CUDA (optional) |

## Model Support

GGUF format only. Tested families:

- Qwen2 / Qwen2.5 (1.5B / 3B / 7B)
- Llama 3 / 3.1 / 3.2 (1B / 3B / 8B)
- Phi-3 / Phi-3.5 mini
- Mistral 7B / Nemo
- Gemma 2 (2B / 9B)
- Llava / Qwen2-VL (vision)

Recommended quantization: **Q4_K_M** for the best quality/size balance.

---

## Installation

### Windows

1. Download `Neth-AI-Windows-x64.exe` from [Releases](../../releases).
2. Run it. Windows SmartScreen may warn — click "More info" → "Run anyway".
3. Open the **Models** tab → **Import GGUF...** → pick a `.gguf` file.
4. Return to **Assistant** — the orb should pulse orange. Start chatting.

### iPadOS

The IPA is **unsigned** — see [Installation (iPadOS)](#installation-ipad-os) below.

1. Download `Neth-AI-iOS-unsigned.ipa` from [Releases](../../releases).
2. Sign or sideload it using one of:
   - **AltStore** / **SideStore** (free 7-day Apple ID cert)
   - **Sideloadly** (free 7-day cert)
   - **TrollStore** (on supported iOS versions, permanent install)
   - An **Apple Developer** account + `codesign` from a Mac
3. Open the **Models** tab → import a `.gguf` via Files (AirDrop, iCloud Drive).
4. Return to **Assistant** — the orb pulses. Speak or type.

### Installation (iPadOS) — unsigned IPA limitations

Because the IPA is **unsigned**, it cannot be installed by tapping it on the
device. Apple requires every iOS application to be signed by a valid
certificate before it will launch. We do not bypass Apple's signing or security
mechanisms. You must sign it yourself using one of the methods above.

- Free Apple ID sideloads expire after 7 days and must be refreshed.
- A paid Apple Developer account gives a 1-year cert.
- TrollStore (where available) gives a permanent install with no expiry.

---

## Local API

Enable in **Settings → Local API** (iOS) or **Tools → Local API** (Windows).

```
GET  /api/tags
POST /api/show
POST /api/generate   # NDJSON streaming when stream:true
POST /api/chat       # NDJSON streaming when stream:true
```

Defaults to `127.0.0.1:11434`. Switch to `0.0.0.0` in Tools → "Expose on local
network" for PC server mode.

---

## PC Server Mode

1. On the PC: open Neth-AI → **Tools** → set bind to `0.0.0.0` → **Start**.
2. Note the PC's local IP (e.g. `192.168.1.10`).
3. On the iPad: **Settings → PC Server Mode** → enter host + port (11434) → enable.
4. The iPad will route inference requests to the PC.

The iPad still runs its own local inference when PC server is off.

---

## Building from source

### iOS

```bash
brew install xcodegen
cd ios/NethAI
xcodegen generate
open NethAI.xcodeproj
# In Xcode: select your device, Cmd+R
```

Or from CLI:

```bash
xcodebuild \
  -project NethAI.xcodeproj \
  -scheme NethAI \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### Windows

```powershell
cd windows\NethAI
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
pip install pyinstaller
pyinstaller build.spec
# Output: dist\Neth-AI-Windows-x64.exe
```

For CUDA-accelerated llama-cpp-python:

```powershell
$env:CMAKE_ARGS="-DGGML_CUDA=on"
pip install llama-cpp-python --upgrade --force-reinstall --no-cache-dir
```

---

## GitHub Actions

Three workflows under `.github/workflows/`:

| Workflow | Trigger | Output |
|---|---|---|
| `build-ios.yml` | tag push / dispatch / release call | unsigned `.ipa` artifact |
| `build-windows.yml` | tag push / dispatch / release call | `.exe` artifact |
| `release.yml` | tag push `v*.*.*` | GitHub Release with both binaries + SHA256SUMS.txt |

The release workflow:

1. Calls `build-ios.yml` → produces `Neth-AI-iOS-unsigned.ipa`
2. Calls `build-windows.yml` → produces `Neth-AI-Windows-x64.exe`
3. Computes `SHA256SUMS.txt`
4. Creates a GitHub Release under the pushed tag with all three assets

## Releases

Push a tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Wait ~30–40 minutes for both platform builds. The release will appear at
[Releases](../../releases) with both binaries attached.

---

## Troubleshooting

### iOS

- **"No model loaded"** — import a GGUF via the Models tab first.
- **"Not a valid GGUF"** — verify the file starts with bytes `47 47 55 46` ("GGUF").
- **App crashes on launch** — the unsigned build needs a valid signature or TrollStore.
- **Speech recognition unavailable** — Settings → Privacy → Speech Recognition, allow Neth-AI.
- **Slow generation** — try a smaller model (1B–3B for A12 chips, 7B+ for M-series).

### Windows

- **"Failed to load model: out of memory"** — use a smaller quant (Q3_K_M) or model.
- **No CUDA acceleration** — install with `CMAKE_ARGS="-DGGML_CUDA=on"` (see above).
- **SmartScreen warning** — expected for unsigned executables; click "Run anyway".
- **Microphone denied** — Settings → Privacy → Microphone → allow Neth-AI.
- **`pyaudio` install fails** — `pip install pipwin; pipwin install pyaudio`.

---

## Known Limitations

- iOS unsigned IPA requires sideloading; we do not bypass Apple's signing.
- Vision model integration is wired for the UI; only models that report vision
  capability (filename heuristics) accept images. Always verify your model
  actually supports vision before relying on it.
- The local API binds to `127.0.0.1` by default — never exposed publicly.
- PC server mode is optional and runs over plain HTTP on your local network.
  Do not expose it to the internet.
- Performance depends on your hardware. Apple A12 / Intel i5 class devices
  can comfortably run 1B–3B Q4_K_M models at usable speeds.

---

## License

MIT. See [LICENSE](LICENSE).

Neth-AI is an original work. Any resemblance to other AI device products is
coincidental and limited to high-level AI-first interaction philosophy.
