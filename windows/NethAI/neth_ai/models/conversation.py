"""Conversation data + persistence."""

from __future__ import annotations

import json
import os
import uuid
from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import List, Optional


@dataclass
class Message:
    role: str  # "user" | "assistant" | "system"
    content: str
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat() + "Z")
    stats: Optional[dict] = None
    model_name: Optional[str] = None
    images: List[str] = field(default_factory=list)  # file paths

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict) -> "Message":
        return cls(**{k: d.get(k) for k in cls.__dataclass_fields__})


@dataclass
class Conversation:
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    title: str = "New Conversation"
    messages: List[Message] = field(default_factory=list)
    model_name: Optional[str] = None
    created_at: str = field(default_factory=lambda: datetime.utcnow().isoformat() + "Z")
    updated_at: str = field(default_factory=lambda: datetime.utcnow().isoformat() + "Z")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "title": self.title,
            "messages": [m.to_dict() for m in self.messages],
            "model_name": self.model_name,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "Conversation":
        c = cls(
            id=d["id"],
            title=d.get("title", "Conversation"),
            model_name=d.get("model_name"),
            created_at=d.get("created_at", datetime.utcnow().isoformat() + "Z"),
            updated_at=d.get("updated_at", datetime.utcnow().isoformat() + "Z"),
        )
        c.messages = [Message.from_dict(m) for m in d.get("messages", [])]
        return c


class ConversationStore:
    def __init__(self, root: Optional[str] = None):
        if root is None:
            root = os.path.join(os.path.expanduser("~"), ".neth-ai", "conversations")
        os.makedirs(root, exist_ok=True)
        self.root = root

    def list_all(self) -> List[Conversation]:
        out = []
        for name in os.listdir(self.root):
            if not name.endswith(".json"):
                continue
            try:
                with open(os.path.join(self.root, name), "r", encoding="utf-8") as f:
                    c = Conversation.from_dict(json.load(f))
                out.append(c)
            except Exception:
                continue
        out.sort(key=lambda c: c.updated_at, reverse=True)
        return out

    def save(self, c: Conversation) -> None:
        path = os.path.join(self.root, f"{c.id}.json")
        c.updated_at = datetime.utcnow().isoformat() + "Z"
        with open(path, "w", encoding="utf-8") as f:
            json.dump(c.to_dict(), f, ensure_ascii=False, indent=2)

    def delete(self, c: Conversation) -> None:
        try:
            os.remove(os.path.join(self.root, f"{c.id}.json"))
        except Exception:
            pass

    def rename(self, c: Conversation, name: str) -> None:
        c.title = name
        self.save(c)
