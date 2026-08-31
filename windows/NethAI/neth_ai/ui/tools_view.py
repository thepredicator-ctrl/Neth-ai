"""Tools view — local API control + PC server mode."""

from __future__ import annotations

from PySide6.QtWidgets import (
    QCheckBox,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from . import theme as T


class ToolsView(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._build_ui()

    def _build_ui(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(18, 18, 18, 18)
        outer.setSpacing(12)

        title = QLabel("Tools")
        title.setObjectName("Title")
        outer.addWidget(title)

        api_group = QGroupBox("Local API (Ollama-style)")
        api_layout = QVBoxLayout(api_group)
        api_layout.addWidget(QLabel("Expose /api/tags, /api/show, /api/generate, /api/chat on this machine."))

        row = QHBoxLayout()
        row.addWidget(QLabel("Bind:"))
        self.bind_edit = QLineEdit("127.0.0.1")
        row.addWidget(self.bind_edit)
        row.addWidget(QLabel("Port:"))
        self.port_edit = QLineEdit("11434")
        self.port_edit.setFixedWidth(80)
        row.addWidget(self.port_edit)
        row.addStretch()
        self.start_btn = QPushButton("Start")
        self.start_btn.setObjectName("Primary")
        self.start_btn.clicked.connect(self._start_api)
        row.addWidget(self.start_btn)
        self.stop_btn = QPushButton("Stop")
        self.stop_btn.clicked.connect(self._stop_api)
        row.addWidget(self.stop_btn)
        api_layout.addLayout(row)

        self.api_status = QLabel("Status: stopped")
        self.api_status.setStyleSheet("color: #6E6E6E;")
        api_layout.addWidget(self.api_status)

        outer.addWidget(api_group)

        server_group = QGroupBox("PC Server Mode")
        sg = QVBoxLayout(server_group)
        sg.addWidget(QLabel("Allow iPads on your local Wi-Fi to use this PC for inference."))
        self.expose_check = QCheckBox("Expose on local network (0.0.0.0)")
        sg.addWidget(self.expose_check)
        sg.addWidget(QLabel("After enabling, your iPad's Neth-AI app can connect to this PC's IP."))
        outer.addWidget(server_group)

        log_group = QGroupBox("API Log")
        lg = QVBoxLayout(log_group)
        self.log = QTextEdit()
        self.log.setReadOnly(True)
        self.log.setMinimumHeight(120)
        lg.addWidget(self.log)
        outer.addWidget(log_group, 1)

        outer.addStretch()

    def _start_api(self) -> None:
        from ..api.server import APIServer
        bind = self.bind_edit.text().strip() or "127.0.0.1"
        port = int(self.port_edit.text().strip() or "11434")
        ok = APIServer.start(host=bind, port=port, log=self.log)
        self.api_status.setText(f"Status: {'running' if ok else 'failed to start'} on {bind}:{port}")

    def _stop_api(self) -> None:
        from ..api.server import APIServer
        APIServer.stop()
        self.api_status.setText("Status: stopped")
