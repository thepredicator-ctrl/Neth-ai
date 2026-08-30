"""Main window — sidebar nav + content stack."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QPushButton,
    QStackedWidget,
    QVBoxLayout,
    QWidget,
)

from .app_state import AppState
from .ui.assistant_view import AssistantView
from .ui.conversations_view import ConversationsView
from .ui.models_view import ModelsView
from .ui.settings_view import SettingsView
from .ui.tools_view import ToolsView
from .ui import theme as T


class NavButton(QPushButton):
    def __init__(self, label: str, icon: str = "", parent=None):
        super().__init__(parent)
        self.setText(f"  {icon}  {label}" if icon else label)
        self.setCheckable(True)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setMinimumHeight(42)
        self.setStyleSheet("""
            QPushButton {
                background: transparent;
                border: none;
                text-align: left;
                padding: 8px 12px;
                color: #6E6E6E;
                font-size: 11pt;
            }
            QPushButton:hover { color: #A8A8A8; background: rgba(255,122,24,0.05); border-radius: 8px; }
            QPushButton:checked {
                color: #FF7A18;
                background: rgba(255,122,24,0.08);
                border-radius: 8px;
                border-left: 2px solid #FF7A18;
            }
        """)


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Neth-AI")
        self.resize(1200, 760)
        self.setMinimumSize(960, 640)

        central = QWidget()
        central.setObjectName("Root")
        self.setCentralWidget(central)

        layout = QHBoxLayout(central)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Sidebar
        sidebar = QWidget()
        sidebar.setFixedWidth(220)
        sidebar.setStyleSheet("background: #0E0E0E; border-right: 1px solid #2A2A2A;")
        sb = QVBoxLayout(sidebar)
        sb.setContentsMargins(14, 18, 14, 14)
        sb.setSpacing(6)

        brand = QLabel("NETH-AI")
        brand.setStyleSheet("color: #FF7A18; font-size: 14pt; font-weight: 700; letter-spacing: 4px; padding: 12px 0 18px 6px;")
        sb.addWidget(brand)

        self.nav_buttons = []
        self.stack = QStackedWidget()
        for idx, (label, icon, widget) in enumerate([
            ("Assistant",    "\u25CF", AssistantView(AppState.instance().engine, AppState.instance().model_manager, AppState.instance().store)),
            ("Conversations", "\u25C9", ConversationsView(AppState.instance().store)),
            ("Models",       "\u25A2", ModelsView(AppState.instance().model_manager, AppState.instance().engine)),
            ("Tools",        "\u25C6", ToolsView()),
            ("Settings",     "\u25CB", SettingsView(AppState.instance().engine)),
        ]):
            btn = NavButton(label, icon)
            btn.clicked.connect(lambda _checked=False, i=idx: self._switch(i))
            sb.addWidget(btn)
            self.nav_buttons.append(btn)
            self.stack.addWidget(widget)

        sb.addStretch()
        footer = QLabel("v0.1.0  -  local")
        footer.setStyleSheet("color: #6E6E6E; font-size: 8pt; padding: 6px;")
        sb.addWidget(footer)

        layout.addWidget(sidebar)

        # Content
        content = QWidget()
        cl = QVBoxLayout(content)
        cl.setContentsMargins(0, 0, 0, 0)
        cl.addWidget(self.stack)
        layout.addWidget(content, 1)

        # status bar
        sb_bar = self.statusBar()
        sb_bar.showMessage("Ready. Engine: llama.cpp  -  Neth-AI 0.1.0")

        self._switch(0)

    def _switch(self, idx: int) -> None:
        for i, b in enumerate(self.nav_buttons):
            b.setChecked(i == idx)
        self.stack.setCurrentIndex(idx)

    def closeEvent(self, e) -> None:
        try:
            from .api.server import APIServer
            APIServer.stop()
        except Exception:
            pass
        super().closeEvent(e)
