"""Main Assistant view: Neth Orb + voice + text input + streaming response."""

from __future__ import annotations

import threading
import time
from typing import Optional

from PySide6.QtCore import QObject, Qt, QThread, Signal, Slot, QTimer
from PySide6.QtGui import QFont, QTextCursor, QKeyEvent
from PySide6.QtWidgets import (
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QScrollArea,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ..engine.llm_engine import (
    InferenceStats,
    LLMError,
    LlamaEngine,
    SamplingParams,
)
from ..models.conversation import Conversation, Message
from ..models.model_manager import InstalledModel
from ..storage.conversation_store import ConversationStore
from ..storage.model_manager import ModelManager
from ..voice.speech import SpeechRecognizer
from .orb_widget import NethOrbWidget
from . import theme as T


class GenerateWorker(QObject):
    token = Signal(str)
    final = Signal(object)  # InferenceStats or None
    error = Signal(str)
    finished = Signal()

    def __init__(self, engine: LlamaEngine, prompt: str, params: SamplingParams):
        super().__init__()
        self._engine = engine
        self._prompt = prompt
        self._params = params

    def run(self) -> None:
        try:
            for tok in self._engine.generate(self._prompt, self._params):
                if tok.is_final:
                    self.final.emit(tok.stats)
                else:
                    self.token.emit(tok.text)
        except LLMError as e:
            self.error.emit(str(e))
        except Exception as e:
            self.error.emit(f"Unexpected error: {e}")
        finally:
            self.finished.emit()


class PromptTextEdit(QTextEdit):
    """Multi-line text input that submits on Enter (Shift+Enter for newline)."""
    submit = Signal()

    def keyPressEvent(self, e: QKeyEvent) -> None:
        if e.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter) and not (e.modifiers() & Qt.ShiftModifier):
            self.submit.emit()
            return
        super().keyPressEvent(e)


class AssistantView(QWidget):
    def __init__(self, engine: LlamaEngine, model_manager: ModelManager, store: ConversationStore, parent=None):
        super().__init__(parent)
        self._engine = engine
        self._model_manager = model_manager
        self._store = store
        self._current_model: Optional[InstalledModel] = None
        self._current_conversation: Optional[Conversation] = None
        self._worker_thread: Optional[QThread] = None
        self._worker: Optional[GenerateWorker] = None
        self._speech = SpeechRecognizer()
        self._speech.transcript.connect(self._on_transcript)
        self._speech.level.connect(self._on_audio_level)
        self._speech.listening_changed.connect(self._on_listening_changed)

        self._build_ui()
        self._refresh_models()
        self._refresh_conversations()

    # ---------- UI ----------
    def _build_ui(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(24, 18, 24, 18)
        outer.setSpacing(10)

        # Top bar
        top = QHBoxLayout()
        top.setSpacing(10)
        self.model_chip = QPushButton("No model")
        self.model_chip.setCursor(Qt.CursorShape.PointingHandCursor)
        self.model_chip.clicked.connect(self._open_model_dialog)
        top.addWidget(self.model_chip)
        top.addStretch()

        self.stop_btn = QPushButton("Stop")
        self.stop_btn.setObjectName("Danger")
        self.stop_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.stop_btn.clicked.connect(self._stop)
        self.stop_btn.hide()
        top.addWidget(self.stop_btn)

        self.stats_label = QLabel("")
        self.stats_label.setFont(T.font_mono(9))
        self.stats_label.setStyleSheet("color: #6E6E6E; padding: 0 8px;")
        top.addWidget(self.stats_label)
        outer.addLayout(top)

        # Orb
        orb_row = QHBoxLayout()
        orb_row.addStretch()
        self.orb = NethOrbWidget(size=240)
        orb_row.addWidget(self.orb)
        orb_row.addStretch()
        outer.addLayout(orb_row)

        self.state_label = QLabel("Ready")
        self.state_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.state_label.setObjectName("Caption")
        outer.addWidget(self.state_label)

        # Response
        self.response_area = QTextEdit()
        self.response_area.setReadOnly(True)
        self.response_area.setPlaceholderText("Speak or type to begin.")
        self.response_area.setMinimumHeight(160)
        outer.addWidget(self.response_area, 1)

        # Input row
        input_row = QHBoxLayout()
        input_row.setSpacing(8)

        self.mic_btn = QPushButton()
        self.mic_btn.setFixedSize(40, 40)
        self.mic_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.mic_btn.setText("\u{1F3A4}")  # microphone emoji
        self.mic_btn.clicked.connect(self._toggle_mic)
        input_row.addWidget(self.mic_btn)

        self.input_field = PromptTextEdit()
        self.input_field.setPlaceholderText("Ask Neth...")
        self.input_field.setFixedHeight(60)
        self.input_field.submit.connect(self._send)
        input_row.addWidget(self.input_field, 1)

        self.send_btn = QPushButton("Send")
        self.send_btn.setObjectName("Primary")
        self.send_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.send_btn.clicked.connect(self._send)
        input_row.addWidget(self.send_btn)

        outer.addLayout(input_row)

        self._update_state(T.ORB_IDLE)
        self._update_send_enabled()

    # ---------- actions ----------
    def _refresh_models(self) -> None:
        models = self._model_manager.list_installed()
        if not models:
            self.model_chip.setText("No model - click to import")
            self._current_model = None
            return
        # pick first
        self._current_model = models[0]
        self.model_chip.setText(f"  {self._current_model.display_name}")
        # auto-load if not loaded
        if not self._engine.is_loaded:
            self._load_current_model()

    def _refresh_conversations(self) -> None:
        convos = self._store.list_all()
        if convos:
            self._current_conversation = convos[0]
        else:
            self._current_conversation = Conversation()
            self._store.save(self._current_conversation)

    def _load_current_model(self) -> None:
        if not self._current_model:
            return
        path = self._model_manager.path_for(self._current_model)
        try:
            self._engine.load_model(path, gpu_layers=99, context_size=4096)
            self._update_state(T.ORB_IDLE)
        except LLMError as e:
            self.response_area.setPlainText(f"Failed to load model: {e}")
            self._update_state(T.ORB_ERROR)

    def _open_model_dialog(self) -> None:
        # open file dialog
        path, _ = QFileDialog.getOpenFileName(self, "Import GGUF Model", "", "GGUF Model (*.gguf)")
        if not path:
            return
        try:
            model = self._model_manager.import_model(path, replace=True)
            self._current_model = model
            self.model_chip.setText(f"  {model.display_name}")
            self._load_current_model()
        except Exception as e:
            self.response_area.setPlainText(f"Import failed: {e}")

    def _toggle_mic(self) -> None:
        if self._speech.is_listening():
            self._speech.stop()
        else:
            self._speech.start()

    def _on_transcript(self, text: str) -> None:
        self.input_field.setPlainText(text)
        cursor = self.input_field.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        self.input_field.setTextCursor(cursor)

    def _on_audio_level(self, level: float) -> None:
        self.orb.set_audio_level(level)

    def _on_listening_changed(self, listening: bool) -> None:
        if listening:
            self._update_state(T.ORB_LISTENING)
        else:
            self._update_state(T.ORB_IDLE if not self._engine.is_loaded else T.ORB_IDLE)

    def _send(self) -> None:
        prompt = self.input_field.toPlainText().strip()
        if not prompt or not self._current_model or not self._engine.is_loaded:
            return
        if self._worker_thread is not None:
            return

        # save user message
        if self._current_conversation is None:
            self._current_conversation = Conversation()
        self._current_conversation.messages.append(Message(role="user", content=prompt))
        self._current_conversation.model_name = self._current_model.file_name
        self._store.save(self._current_conversation)

        self.input_field.clear()
        self.response_area.clear()
        self._update_state(T.ORB_THINKING)
        self.stop_btn.show()
        self._update_send_enabled()

        # build prompt from history
        full_prompt = self._build_prompt(prompt)

        # worker thread
        self._worker_thread = QThread()
        self._worker = GenerateWorker(self._engine, full_prompt, SamplingParams(max_tokens=512))
        self._worker.moveToThread(self._worker_thread)
        self._worker_thread.started.connect(self._worker.run)
        self._worker.token.connect(self._on_token)
        self._worker.final.connect(self._on_final)
        self._worker.error.connect(self._on_error)
        self._worker.finished.connect(self._on_worker_finished)
        self._worker_thread.start()

    def _build_prompt(self, user: str) -> str:
        if self._current_conversation is None:
            return user
        s = "<|im_start|>system\nYou are Neth-AI, a helpful local assistant running entirely on-device. Be concise.<|im_end|>\n"
        for m in self._current_conversation.messages[-8:]:
            s += f"<|im_start|>{m.role}\n{m.content}<|im_end|>\n"
        s += f"<|im_start|>assistant\n"
        return s

    @Slot(str)
    def _on_token(self, text: str) -> None:
        if self._worker_thread is None:
            return
        # state transition on first token
        if self.orb._state != T.ORB_GENERATING:
            self._update_state(T.ORB_GENERATING)
        cursor = self.response_area.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        cursor.insertText(text)
        self.response_area.setTextCursor(cursor)
        self.response_area.ensureCursorVisible()

    @Slot(object)
    def _on_final(self, stats) -> None:
        if stats is None:
            return
        if isinstance(stats, InferenceStats):
            self.stats_label.setText(stats.formatted_summary())
            self._update_state(T.ORB_COMPLETE)
            # save assistant message
            if self._current_conversation is not None:
                self._current_conversation.messages.append(
                    Message(
                        role="assistant",
                        content=self.response_area.toPlainText(),
                        stats={
                            "tokens_per_second": stats.tokens_per_second,
                            "time_to_first_token": stats.time_to_first_token,
                            "total_tokens": stats.total_tokens,
                            "cuda_accelerated": stats.cuda_accelerated,
                            "gpu_layers": stats.gpu_layers,
                        },
                        model_name=self._current_model.file_name if self._current_model else None,
                    )
                )
                self._store.save(self._current_conversation)

    @Slot(str)
    def _on_error(self, msg: str) -> None:
        self.response_area.append(f"\n[error] {msg}")
        self._update_state(T.ORB_ERROR)

    @Slot()
    def _on_worker_finished(self) -> None:
        if self._worker_thread:
            self._worker_thread.quit()
            self._worker_thread.wait()
            self._worker_thread = None
            self._worker = None
        self.stop_btn.hide()
        self._update_send_enabled()
        QTimer.singleShot(1500, lambda: self._update_state(T.ORB_IDLE) if self.orb._state == T.ORB_COMPLETE else None)

    def _stop(self) -> None:
        if self._engine:
            self._engine.cancel()
        self._update_state(T.ORB_COMPLETE)

    def _update_state(self, state: str) -> None:
        self.orb.set_state(state)
        self.state_label.setText(T.STATE_LABEL.get(state, "").upper())

    def _update_send_enabled(self) -> None:
        can = self._engine.is_loaded and self._worker_thread is None
        self.send_btn.setEnabled(can)
