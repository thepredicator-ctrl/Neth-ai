"""Settings view."""

from __future__ import annotations

from PySide6.QtWidgets import (
    QGroupBox,
    QLabel,
    QVBoxLayout,
    QWidget,
)

from ..engine.llm_engine import LlamaEngine
from . import theme as T


class SettingsView(QWidget):
    def __init__(self, engine: LlamaEngine, parent=None):
        super().__init__(parent)
        self._engine = engine
        self._build_ui()

    def _build_ui(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(18, 18, 18, 18)
        outer.setSpacing(12)

        title = QLabel("Settings")
        title.setObjectName("Title")
        outer.addWidget(title)

        engine_group = QGroupBox("Engine")
        eg = QVBoxLayout(engine_group)
        eg.addWidget(QLabel(f"Backend:  llama-cpp-python"))
        eg.addWidget(QLabel(f"CUDA acceleration:  {'yes' if self._engine.cuda_accelerated else 'no'}"))
        eg.addWidget(QLabel(f"GPU layers:  {self._engine.gpu_layers}"))
        eg.addWidget(QLabel(f"Context size:  {self._engine.context_size}"))
        eg.addWidget(QLabel(f"Loaded model:  {self._engine.loaded_model_name or '-'}"))
        outer.addWidget(engine_group)

        about_group = QGroupBox("About")
        ag = QVBoxLayout(about_group)
        ag.addWidget(QLabel("Neth-AI for Windows"))
        ag.addWidget(QLabel("Version: 0.1.0"))
        ag.addWidget(QLabel("Engine: llama.cpp (via llama-cpp-python)"))
        ag.addWidget(QLabel("UI: PySide6 (Qt 6)"))
        outer.addWidget(about_group)

        outer.addStretch()
