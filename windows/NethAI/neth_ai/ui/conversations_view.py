"""Conversations view: list + rename + delete + search."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ..models.conversation import Conversation
from ..storage.conversation_store import ConversationStore
from . import theme as T


class ConversationsView(QWidget):
    def __init__(self, store: ConversationStore, parent=None):
        super().__init__(parent)
        self._store = store
        self._build_ui()
        self._refresh()

    def _build_ui(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(18, 18, 18, 18)
        outer.setSpacing(10)

        title = QLabel("Conversations")
        title.setObjectName("Title")
        outer.addWidget(title)

        self.search = QLineEdit()
        self.search.setPlaceholderText("Search conversations...")
        self.search.textChanged.connect(self._refresh)
        outer.addWidget(self.search)

        row = QHBoxLayout()
        row.setSpacing(8)
        self.new_btn = QPushButton("New")
        self.new_btn.clicked.connect(self._new_convo)
        self.rename_btn = QPushButton("Rename")
        self.rename_btn.clicked.connect(self._rename)
        self.delete_btn = QPushButton("Delete")
        self.delete_btn.clicked.connect(self._delete)
        row.addWidget(self.new_btn)
        row.addWidget(self.rename_btn)
        row.addWidget(self.delete_btn)
        row.addStretch()
        outer.addLayout(row)

        self.list = QListWidget()
        self.list.itemClicked.connect(self._load_item)
        outer.addWidget(self.list, 1)

        self.detail = QTextEdit()
        self.detail.setReadOnly(True)
        self.detail.setPlaceholderText("Select a conversation to view its messages.")
        self.detail.setMinimumHeight(160)
        outer.addWidget(self.detail, 1)

    def _refresh(self) -> None:
        all_convos = self._store.list_all()
        q = self.search.text().strip().lower()
        if q:
            filtered = []
            for c in all_convos:
                if q in c.title.lower() or any(q in m.content.lower() for m in c.messages):
                    filtered.append(c)
            all_convos = filtered
        self.list.clear()
        for c in all_convos:
            item = QListWidgetItem(f"{c.title}\n  {len(c.messages)} messages")
            item.setData(Qt.ItemDataRole.UserRole, c)
            self.list.addItem(item)

    def _new_convo(self) -> None:
        c = Conversation(title=f"Conversation {len(self._store.list_all()) + 1}")
        self._store.save(c)
        self._refresh()

    def _rename(self) -> None:
        item = self.list.currentItem()
        if not item:
            return
        c = item.data(Qt.ItemDataRole.UserRole)
        from PySide6.QtWidgets import QInputDialog
        name, ok = QInputDialog.getText(self, "Rename", "New name:", text=c.title)
        if ok and name:
            self._store.rename(c, name)
            self._refresh()

    def _delete(self) -> None:
        item = self.list.currentItem()
        if not item:
            return
        c = item.data(Qt.ItemDataRole.UserRole)
        self._store.delete(c)
        self._refresh()
        self.detail.clear()

    def _load_item(self, item: QListWidgetItem) -> None:
        c = item.data(Qt.ItemDataRole.UserRole)
        text = ""
        for m in c.messages:
            text += f"[{m.role.upper()}]\n{m.content}\n\n"
        self.detail.setPlainText(text or "(empty)")
