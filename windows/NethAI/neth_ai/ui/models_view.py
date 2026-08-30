"""Models manager view."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFileDialog,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from ..engine.llm_engine import LLMError, LlamaEngine
from ..storage.model_manager import ModelManager
from . import theme as T


class ModelsView(QWidget):
    def __init__(self, model_manager: ModelManager, engine: LlamaEngine, parent=None):
        super().__init__(parent)
        self._model_manager = model_manager
        self._engine = engine
        self._build_ui()
        self._refresh()

    def _build_ui(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(18, 18, 18, 18)
        outer.setSpacing(10)

        title = QLabel("Models")
        title.setObjectName("Title")
        outer.addWidget(title)

        row = QHBoxLayout()
        self.import_btn = QPushButton("Import GGUF...")
        self.import_btn.setObjectName("Primary")
        self.import_btn.clicked.connect(self._import)
        self.refresh_btn = QPushButton("Refresh")
        self.refresh_btn.clicked.connect(self._refresh)
        row.addWidget(self.import_btn)
        row.addWidget(self.refresh_btn)
        row.addStretch()
        outer.addLayout(row)

        self.table = QTableWidget(0, 6)
        self.table.setHorizontalHeaderLabels(["Name", "Params", "Quant", "Size", "Vision", "Loaded"])
        self.table.horizontalHeader().setStretchLastSection(False)
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.table.cellDoubleClicked.connect(self._load_model)
        outer.addWidget(self.table, 1)

        self.delete_btn = QPushButton("Delete Selected")
        self.delete_btn.clicked.connect(self._delete_selected)
        outer.addWidget(self.delete_btn)

    def _refresh(self) -> None:
        models = self._model_manager.list_installed()
        self.table.setRowCount(len(models))
        for i, m in enumerate(models):
            self.table.setItem(i, 0, QTableWidgetItem(m.display_name))
            self.table.setItem(i, 1, QTableWidgetItem(m.parameter_count or "-"))
            self.table.setItem(i, 2, QTableWidgetItem(m.quantization or "-"))
            self.table.setItem(i, 3, QTableWidgetItem(m.formatted_size()))
            self.table.setItem(i, 4, QTableWidgetItem("yes" if m.supports_vision else "no"))
            loaded = self._engine.loaded_model_name == m.file_name
            self.table.setItem(i, 5, QTableWidgetItem("loaded" if loaded else "-"))
            # store model in first cell
            self.table.item(i, 0).setData(Qt.ItemDataRole.UserRole, m)
        self.table.resizeColumnsToContents()

    def _import(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Import GGUF Model", "", "GGUF (*.gguf)")
        if not path:
            return
        try:
            self._model_manager.import_model(path, replace=True)
            self._refresh()
        except Exception as e:
            from PySide6.QtWidgets import QMessageBox
            QMessageBox.warning(self, "Import failed", str(e))

    def _load_model(self, row: int, _col: int) -> None:
        item = self.table.item(row, 0)
        if not item:
            return
        m = item.data(Qt.ItemDataRole.UserRole)
        try:
            self._engine.load_model(self._model_manager.path_for(m), gpu_layers=99, context_size=4096)
            self._refresh()
        except LLMError as e:
            from PySide6.QtWidgets import QMessageBox
            QMessageBox.warning(self, "Load failed", str(e))

    def _delete_selected(self) -> None:
        rows = self.table.selectionModel().selectedRows()
        if not rows:
            return
        for idx in rows:
            item = self.table.item(idx.row(), 0)
            if item:
                m = item.data(Qt.ItemDataRole.UserRole)
                self._model_manager.delete(m)
        self._refresh()
