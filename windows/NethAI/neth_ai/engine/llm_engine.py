"""Neth-AI inference engine using llama-cpp-python.
Real GGUF inference, streaming generation, real tok/s + TTFT measurement.
"""

from __future__ import annotations

import os
import threading
import time
from dataclasses import dataclass, field
from typing import Callable, Iterator, List, Optional

try:
    from llama_cpp import Llama
    HAVE_LLAMA = True
except Exception as _e:  # pragma: no cover
    HAVE_LLAMA = False
    _LLAMA_IMPORT_ERROR = str(_e)


GGUF_MAGIC = b"GGUF"


@dataclass
class InferenceStats:
    tokens_per_second: float = 0.0
    time_to_first_token: float = 0.0
    total_tokens: int = 0
    prompt_tokens: int = 0
    generation_duration: float = 0.0
    context_size: int = 4096
    memory_resident_mb: float = 0.0
    metal_accelerated: bool = False  # always False on Windows; we use CUDA instead
    cuda_accelerated: bool = False
    gpu_layers: int = 0

    def formatted_rate(self) -> str:
        return f"{self.tokens_per_second:.1f} tok/s"

    def formatted_ttft(self) -> str:
        if self.time_to_first_token < 1.0:
            return f"{self.time_to_first_token * 1000:.0f}ms TTFT"
        return f"{self.time_to_first_token:.1f}s TTFT"

    def formatted_summary(self) -> str:
        return f"{self.formatted_rate()}  -  {self.formatted_ttft()}"


@dataclass
class SamplingParams:
    temperature: float = 0.7
    top_p: float = 0.9
    top_k: int = 40
    max_tokens: int = 512
    repeat_penalty: float = 1.1


@dataclass
class EngineToken:
    text: str
    is_final: bool = False
    stats: Optional[InferenceStats] = None


class LLMError(Exception):
    pass


class LlamaEngine:
    """Wraps llama-cpp-python. Provides load/unload + streaming generate."""

    def __init__(self):
        self._llm: Optional[Llama] = None
        self._lock = threading.RLock()
        self._loaded_path: Optional[str] = None
        self._loaded_name: Optional[str] = None
        self._cancelled = threading.Event()
        self._context_size = 4096
        self._gpu_layers = 0
        self._cuda = False

    # ---------- properties ----------
    @property
    def is_loaded(self) -> bool:
        with self._lock:
            return self._llm is not None

    @property
    def loaded_model_name(self) -> Optional[str]:
        return self._loaded_name

    @property
    def context_size(self) -> int:
        return self._context_size

    @property
    def cuda_accelerated(self) -> bool:
        return self._cuda

    @property
    def gpu_layers(self) -> int:
        return self._gpu_layers

    # ---------- GGUF validation ----------
    @staticmethod
    def is_gguf(path: str) -> bool:
        try:
            with open(path, "rb") as f:
                return f.read(4) == GGUF_MAGIC
        except Exception:
            return False

    # ---------- load / unload ----------
    def load_model(self, path: str, gpu_layers: int = 99, context_size: int = 4096) -> None:
        if not HAVE_LLAMA:
            raise LLMError(f"llama-cpp-python is not installed: {_LLAMA_IMPORT_ERROR}")
        if not os.path.exists(path):
            raise LLMError(f"Model not found: {path}")
        if not self.is_gguf(path):
            raise LLMError("File is not a valid GGUF model (missing GGUF magic header).")

        # unload existing
        self.unload_model()

        try:
            with self._lock:
                # detect CUDA availability
                try:
                    import llama_cpp
                    cuda = getattr(llama_cpp, "_IS_CUDA_AVAILABLE", False)
                except Exception:
                    cuda = False
                self._cuda = cuda

                self._llm = Llama(
                    model_path=path,
                    n_gpu_layers=gpu_layers,
                    n_ctx=context_size,
                    verbose=False,
                    use_mlock=True,
                )
                self._loaded_path = path
                self._loaded_name = os.path.basename(path)
                self._context_size = context_size
                self._gpu_layers = gpu_layers
                self._cancelled.clear()
        except Exception as e:
            self._llm = None
            self._loaded_path = None
            raise LLMError(f"Failed to load model: {e}") from e

    def unload_model(self) -> None:
        with self._lock:
            if self._llm is not None:
                try:
                    del self._llm
                except Exception:
                    pass
            self._llm = None
            self._loaded_path = None
            self._loaded_name = None

    # ---------- generation ----------
    def generate(self, prompt: str, params: SamplingParams) -> Iterator[EngineToken]:
        """Synchronous generator that yields EngineToken items."""
        with self._lock:
            llm = self._llm
        if llm is None:
            raise LLMError("No model loaded.")

        self._cancelled.clear()
        start = time.perf_counter()
        first_token_time: Optional[float] = None
        token_count = 0

        try:
            stream = llm(
                prompt,
                max_tokens=params.max_tokens,
                temperature=params.temperature,
                top_p=params.top_p,
                top_k=params.top_k,
                repeat_penalty=params.repeat_penalty,
                stream=True,
                stop=["<|im_end|>", "</s>", "<|end|>"],
            )
            for chunk in stream:
                if self._cancelled.is_set():
                    break
                delta = chunk.get("choices", [{}])[0].get("delta", {})
                text = delta.get("content", "")
                token_count += 1
                if first_token_time is None:
                    first_token_time = time.perf_counter() - start
                if text:
                    yield EngineToken(text=text, is_final=False)
        except Exception as e:
            raise LLMError(f"Inference failed: {e}") from e

        duration = time.perf_counter() - start
        tps = (token_count / duration) if duration > 0 else 0.0
        ttft = first_token_time or 0.0
        stats = InferenceStats(
            tokens_per_second=tps,
            time_to_first_token=ttft,
            total_tokens=token_count,
            prompt_tokens=0,
            generation_duration=duration,
            context_size=self._context_size,
            memory_resident_mb=self._resident_mb(),
            cuda_accelerated=self._cuda,
            gpu_layers=self._gpu_layers,
        )
        yield EngineToken(text="", is_final=True, stats=stats)

    def cancel(self) -> None:
        self._cancelled.set()

    @staticmethod
    def _resident_mb() -> float:
        try:
            import psutil
            return psutil.Process().memory_info().rss / (1024.0 * 1024.0)
        except Exception:
            return 0.0
