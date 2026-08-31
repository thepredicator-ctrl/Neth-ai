"""Installed GGUF model representation + ModelManager."""

from __future__ import annotations

import os
import re
import shutil
import uuid
from dataclasses import dataclass, field
from typing import List, Optional


GGUF_MAGIC = b"GGUF"

QUANT_PATTERNS = [
    "Q8_0", "Q6_K", "Q5_K_M", "Q5_K_S", "Q5_1", "Q5_0",
    "Q4_K_M", "Q4_K_S", "Q4_1", "Q4_0",
    "Q3_K_M", "Q3_K_S", "Q3_K_L", "Q2_K", "F16", "F32",
]

VISION_KEYWORDS = ["vision", "vl", "llava", "moondream", "qwen2-vl", "minicpm-v", "phi-3-vision", "internvl"]


@dataclass
class InstalledModel:
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    file_name: str = ""
    display_name: str = ""
    file_size: int = 0
    date_added: str = ""
    quantization: Optional[str] = None
    parameter_count: Optional[str] = None
    supports_vision: bool = False
    path: str = ""

    def formatted_size(self) -> str:
        n = float(self.file_size)
        for unit in ["B", "KB", "MB", "GB", "TB"]:
            if n < 1024.0 or unit == "TB":
                return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
            n /= 1024.0
        return f"{n:.1f} TB"

    @classmethod
    def from_file(cls, path: str) -> "InstalledModel":
        name = os.path.basename(path)
        return cls(
            file_name=name,
            display_name=cls._guess_display(name),
            file_size=os.path.getsize(path) if os.path.exists(path) else 0,
            date_added="",
            quantization=cls._guess_quant(name),
            parameter_count=cls._guess_params(name),
            supports_vision=cls._guess_vision(name),
            path=path,
        )

    @staticmethod
    def _guess_display(name: str) -> str:
        n = os.path.splitext(name)[0]
        n = n.replace("_", " ").replace("-", " ")
        return n.title()

    @staticmethod
    def _guess_quant(name: str) -> Optional[str]:
        up = name.upper()
        for q in QUANT_PATTERNS:
            if q in up:
                return q
        return None

    @staticmethod
    def _guess_params(name: str) -> Optional[str]:
        m = re.search(r"(\d+(?:\.\d+)?)\s*[bB]", name)
        if m:
            return f"{m.group(1)}B"
        return None

    @staticmethod
    def _guess_vision(name: str) -> bool:
        low = name.lower()
        return any(k in low for k in VISION_KEYWORDS)


class ModelManager:
    def __init__(self, root: Optional[str] = None):
        if root is None:
            root = os.path.join(os.path.expanduser("~"), ".neth-ai", "models")
        os.makedirs(root, exist_ok=True)
        self.root = root

    def list_installed(self) -> List[InstalledModel]:
        out = []
        for name in os.listdir(self.root):
            if not name.lower().endswith(".gguf"):
                continue
            full = os.path.join(self.root, name)
            if not os.path.isfile(full):
                continue
            out.append(InstalledModel.from_file(full))
        out.sort(key=lambda m: m.display_name)
        return out

    def import_model(self, source_path: str, replace: bool = False) -> InstalledModel:
        if not os.path.exists(source_path):
            raise FileNotFoundError(source_path)
        with open(source_path, "rb") as f:
            if f.read(4) != GGUF_MAGIC:
                raise ValueError("Not a valid GGUF file (missing GGUF magic header).")
        dest = os.path.join(self.root, os.path.basename(source_path))
        if os.path.exists(dest) and not replace:
            raise FileExistsError("A model with this name already exists.")
        if os.path.exists(dest):
            os.remove(dest)
        shutil.copyfile(source_path, dest)
        return InstalledModel.from_file(dest)

    def delete(self, model: InstalledModel) -> None:
        try:
            os.remove(model.path)
        except Exception:
            pass

    def path_for(self, model: InstalledModel) -> str:
        return os.path.join(self.root, model.file_name)
