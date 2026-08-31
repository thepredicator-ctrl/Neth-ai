"""Neth-AI design system: black + glowing orange AI-device identity."""

from PySide6.QtGui import QColor, QFont, QPainter

# Palette
NETH_VOID = QColor(0x00, 0x00, 0x00)
NETH_BLACK = QColor(0x05, 0x05, 0x05)
NETH_CHARCOAL = QColor(0x12, 0x12, 0x12)
NETH_CHARCOAL_RAISED = QColor(0x1A, 0x1A, 0x1A)
NETH_PANEL = QColor(0x0E, 0x0E, 0x0E)

NETH_ORANGE = QColor(0xFF, 0x7A, 0x18)
NETH_ORANGE_BRIGHT = QColor(0xFF, 0x9A, 0x3C)
NETH_ORANGE_DEEP = QColor(0xE0, 0x5A, 0x0A)
NETH_AMBER = QColor(0xFF, 0xB3, 0x47)
NETH_EMBER = QColor(0xFF, 0xD2, 0x7A)

NETH_TEXT_PRIMARY = QColor(0xF4, 0xF4, 0xF4)
NETH_TEXT_SECONDARY = QColor(0xA8, 0xA8, 0xA8)
NETH_TEXT_TERTIARY = QColor(0x6E, 0x6E, 0x6E)
NETH_HAIRLINE = QColor(0x2A, 0x2A, 0x2A)
NETH_HAIRLINE_WARM = QColor(0x3A, 0x24, 0x18)
NETH_ERROR = QColor(0xFF, 0x5A, 0x2A)

# Orb states
ORB_IDLE = "idle"
ORB_LISTENING = "listening"
ORB_THINKING = "thinking"
ORB_GENERATING = "generating"
ORB_COMPLETE = "complete"
ORB_ERROR = "error"

STATE_LABEL = {
    ORB_IDLE: "Ready",
    ORB_LISTENING: "Listening",
    ORB_THINKING: "Thinking",
    ORB_GENERATING: "Generating",
    ORB_COMPLETE: "Done",
    ORB_ERROR: "Error",
}

STATE_GLOW = {
    ORB_IDLE: QColor(0xFF, 0x7A, 0x18, 140),
    ORB_LISTENING: QColor(0xFF, 0xB3, 0x47, 217),
    ORB_THINKING: QColor(0xFF, 0x9A, 0x3C, 242),
    ORB_GENERATING: QColor(0xFF, 0x7A, 0x18, 255),
    ORB_COMPLETE: QColor(0xFF, 0xD2, 0x7A, 178),
    ORB_ERROR: QColor(0xFF, 0x5A, 0x2A, 230),
}

STATE_PULSE_PERIOD_S = {
    ORB_IDLE: 3.4,
    ORB_LISTENING: 1.1,
    ORB_THINKING: 0.7,
    ORB_GENERATING: 0.45,
    ORB_COMPLETE: 2.2,
    ORB_ERROR: 0.9,
}


def font_display(size: int = 28, bold: bool = True) -> QFont:
    f = QFont()
    f.setFamilies(["Segoe UI", "Inter", "SF Pro Display", "Helvetica Neue", "Arial"])
    f.setPointSize(size)
    f.setBold(bold)
    return f


def font_body(size: int = 11) -> QFont:
    f = QFont()
    f.setFamilies(["Segoe UI", "Inter", "SF Pro Text", "Helvetica Neue", "Arial"])
    f.setPointSize(size)
    return f


def font_mono(size: int = 9) -> QFont:
    f = QFont()
    f.setFamilies(["Cascadia Mono", "JetBrains Mono", "Consolas", "Menlo", "Courier New"])
    f.setPointSize(size)
    return f


APP_QSS = """
* {
    color: #F4F4F4;
    background: transparent;
}
QMainWindow, QWidget#Root {
    background: #000000;
}
QLabel { color: #F4F4F4; }
QLabel#Tertiary { color: #6E6E6E; }
QLabel#Secondary { color: #A8A8A8; }
QLabel#Title { font-size: 14pt; font-weight: 600; }
QLabel#Caption { font-size: 8pt; color: #6E6E6E; letter-spacing: 2px; }
QPushButton {
    background: #121212;
    border: 1px solid #2A2A2A;
    border-radius: 8px;
    padding: 8px 14px;
    color: #F4F4F4;
}
QPushButton:hover {
    background: #1A1A1A;
    border-color: #FF7A18;
}
QPushButton:pressed { background: #0E0E0E; }
QPushButton#Primary {
    background: #FF7A18;
    color: #000000;
    border: 1px solid #FF9A3C;
    font-weight: 600;
}
QPushButton#Primary:hover {
    background: #FF9A3C;
}
QPushButton#Primary:disabled {
    background: #1A1A1A;
    color: #6E6E6E;
    border-color: #2A2A2A;
}
QPushButton#Danger {
    background: rgba(255, 90, 42, 0.18);
    color: #FF5A2A;
    border: 1px solid rgba(255, 90, 42, 0.4);
    border-radius: 14px;
    padding: 6px 12px;
}
QListWidget, QListView, QTextEdit, QPlainTextEdit, QLineEdit, QTableWidget, QTreeWidget {
    background: #0E0E0E;
    border: 1px solid #2A2A2A;
    border-radius: 10px;
    padding: 8px;
    color: #F4F4F4;
    selection-background-color: rgba(255, 122, 24, 0.18);
    selection-color: #FF9A3C;
}
QListWidget::item:hover, QListView::item:hover {
    background: rgba(255, 122, 24, 0.08);
}
QTabWidget::pane {
    border: 1px solid #2A2A2A;
    border-radius: 10px;
    top: -1px;
}
QTabBar::tab {
    background: transparent;
    color: #6E6E6E;
    padding: 8px 18px;
    border: none;
}
QTabBar::tab:selected {
    color: #FF7A18;
    border-bottom: 2px solid #FF7A18;
}
QScrollBar:vertical {
    background: transparent;
    width: 8px;
    margin: 0;
}
QScrollBar::handle:vertical {
    background: #2A2A2A;
    border-radius: 4px;
    min-height: 32px;
}
QScrollBar::handle:vertical:hover { background: #FF7A18; }
QScrollBar::add-line, QScrollBar::sub-line { height: 0; }
QStatusBar { background: #0E0E0E; border-top: 1px solid #2A2A2A; color: #6E6E6E; }
QGroupBox {
    border: 1px solid #2A2A2A;
    border-radius: 10px;
    margin-top: 14px;
    padding: 12px;
}
QGroupBox::title {
    subcontrol-origin: margin;
    subcontrol-position: top left;
    padding: 0 6px;
    color: #FF9A3C;
    font-weight: 600;
}
QCheckBox { color: #F4F4F4; }
QCheckBox::indicator {
    width: 16px; height: 16px;
    border-radius: 4px;
    border: 1px solid #2A2A2A;
    background: #0E0E0E;
}
QCheckBox::indicator:checked {
    background: #FF7A18;
    border-color: #FF9A3C;
}
QComboBox {
    background: #0E0E0E;
    border: 1px solid #2A2A2A;
    border-radius: 8px;
    padding: 6px 10px;
    color: #F4F4F4;
}
QComboBox QAbstractItemView {
    background: #121212;
    border: 1px solid #2A2A2A;
    selection-background-color: rgba(255, 122, 24, 0.18);
}
"""
