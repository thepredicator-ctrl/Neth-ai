"""Global app state — singleton accessible from anywhere."""

from __future__ import annotations

from typing import Optional

from .engine.llm_engine import LlamaEngine
from .storage.conversation_store import ConversationStore
from .storage.model_manager import ModelManager


class AppState:
    _inst: Optional["AppState"] = None

    def __init__(self):
        self.engine = LlamaEngine()
        self.model_manager = ModelManager()
        self.store = ConversationStore()

    @classmethod
    def instance(cls) -> "AppState":
        if cls._inst is None:
            cls._inst = AppState()
        return cls._inst
