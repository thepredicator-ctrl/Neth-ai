# Neth-AI Local API

Optional Ollama-style HTTP API exposed by Neth-AI.

## Endpoints

### `GET /api/tags`

List installed GGUF models.

**Response**
```json
{
  "models": [
    {
      "name": "qwen2-7b-instruct.Q4_K_M.gguf",
      "size": 4370000000,
      "quant": "Q4_K_M",
      "params": "7B",
      "vision": false
    }
  ]
}
```

### `POST /api/show`

Show model info (placeholder; returns `{"info": "ok"}`).

### `POST /api/generate`

Generate text from a prompt.

**Request**
```json
{
  "prompt": "What is the speed of light?",
  "stream": true,
  "temperature": 0.7,
  "top_p": 0.9,
  "top_k": 40,
  "num_predict": 512,
  "repeat_penalty": 1.1
}
```

**Response (stream=true, NDJSON)**
```
{"model": "qwen2-7b-instruct.Q4_K_M.gguf", "response": "The", "done": false}
{"model": "qwen2-7b-instruct.Q4_K_M.gguf", "response": " speed", "done": false}
{"model": "qwen2-7b-instruct.Q4_K_M.gguf", "response": "", "done": true, "stats": {"tokens_per_second": 14.2, "time_to_first_token": 1.7, "total_tokens": 42}}
```

### `POST /api/chat`

Chat with messages.

**Request**
```json
{
  "messages": [
    {"role": "system", "content": "You are Neth-AI."},
    {"role": "user", "content": "Hello!"}
  ],
  "stream": true
}
```

**Response (stream=true, NDJSON)**
```
{"model": "...", "message": {"role": "assistant", "content": "Hi"}, "done": false}
{"model": "...", "message": {"role": "assistant", "content": ""}, "done": true, "stats": {...}}
```

## Default bind

`127.0.0.1:11434` — never exposed publicly.

## PC server mode

Switch bind to `0.0.0.0` in Tools → "Expose on local network" to allow
iPad connections over your local Wi-Fi.

**Do not expose the API to the public internet.** It has no authentication.
