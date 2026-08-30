"""Voice input via SpeechRecognition + PyAudio. On-device where available."""

from __future__ import annotations

import threading
from typing import Optional

from PySide6.QtCore import QObject, Signal, Slot

try:
    import speech_recognition as sr
    HAVE_SR = True
except Exception:
    HAVE_SR = False

try:
    import pyaudio
    HAVE_PA = True
except Exception:
    HAVE_PA = False


class SpeechRecognizer(QObject):
    transcript = Signal(str)
    level = Signal(float)
    listening_changed = Signal(bool)
    error = Signal(str)

    def __init__(self):
        super().__init__()
        self._listening = False
        self._thread: Optional[threading.Thread] = None
        self._stop_evt = threading.Event()

    def is_listening(self) -> bool:
        return self._listening

    def start(self) -> None:
        if not HAVE_SR:
            self.error.emit("speech_recognition library not installed")
            return
        if self._listening:
            return
        self._stop_evt.clear()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop_evt.set()

    def _run(self) -> None:
        try:
            r = sr.Recognizer()
            with sr.Microphone() as source:
                r.adjust_for_ambient_noise(source, duration=0.4)
                self.listening_changed.emit(True)
                while not self._stop_evt.is_set():
                    try:
                        audio = r.listen(source, phrase_time_limit=8, timeout=None)
                        try:
                            text = r.recognize_whisper_local(audio) if hasattr(r, "recognize_whisper_local") else None
                            if text is None:
                                text = r.recognize_google(audio)
                        except Exception:
                            text = ""
                        if text:
                            self.transcript.emit(text)
                        self.level.emit(0.2)
                    except sr.WaitTimeoutError:
                        pass
            self.listening_changed.emit(False)
        except Exception as e:
            self.error.emit(str(e))
            self.listening_changed.emit(False)
