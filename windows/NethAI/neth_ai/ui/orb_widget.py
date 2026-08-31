"""NethOrbWidget — the signature animated AI-device orb.
Pure QPainter + QTimer. Multi-layer: halo, rotating energy rings, particle field,
radial-gradient core, specular highlight, inner waveform during listen/generate.
"""

from __future__ import annotations

import math
import random
import time
from typing import List, Optional, Tuple

from PySide6.QtCore import QPointF, QRectF, QSize, Qt, QTimer, Signal
from PySide6.QtGui import (
    QBrush,
    QColor,
    QConicalGradient,
    QFont,
    QLinearGradient,
    QPainter,
    QPaintEvent,
    QPalette,
    QPen,
    QRadialGradient,
)
from PySide6.QtWidgets import QWidget

from .theme import (
    NETH_AMBER,
    NETH_BLACK,
    NETH_CHARCOAL,
    NETH_EMBER,
    NETH_ERROR,
    NETH_ORANGE,
    NETH_ORANGE_BRIGHT,
    NETH_ORANGE_DEEP,
    NETH_TEXT_SECONDARY,
    ORB_COMPLETE,
    ORB_ERROR,
    ORB_GENERATING,
    ORB_IDLE,
    ORB_LISTENING,
    ORB_THINKING,
    STATE_GLOW,
    STATE_LABEL,
    STATE_PULSE_PERIOD_S,
    font_body,
    font_mono,
)


class NethOrbWidget(QWidget):
    """The animated Neth Orb. Set state via set_state()."""

    stateChanged = Signal(str)

    def __init__(self, parent: Optional[QWidget] = None, size: int = 280):
        super().__init__(parent)
        self._size = size
        self._state = ORB_IDLE
        self._audio_level = 0.0
        self._start = time.perf_counter()
        self._rng = random.Random(0xC0FFEE)
        self._particles: List[Tuple[float, float, float]] = self._init_particles(28)
        self.setFixedSize(size, size)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, False)
        self.setAutoFillBackground(False)

        # 60 FPS timer
        self._timer = QTimer(self)
        self._timer.setTimerType(Qt.TimerType.PreciseTimer)
        self._timer.setInterval(16)
        self._timer.timeout.connect(self.update)
        self._timer.start()

    def _init_particles(self, n: int) -> List[Tuple[float, float, float]]:
        out = []
        for _ in range(n):
            angle = self._rng.uniform(0, 2 * math.pi)
            radius = self._rng.uniform(0.62, 0.92)
            speed = self._rng.uniform(0.6, 1.4)
            out.append((angle, radius, speed))
        return out

    # ---------- public API ----------
    def set_state(self, state: str) -> None:
        if state == self._state:
            return
        self._state = state
        self.stateChanged.emit(state)
        # adjust particle count for new state
        count = {
            ORB_IDLE: 14,
            ORB_LISTENING: 24,
            ORB_THINKING: 32,
            ORB_GENERATING: 40,
            ORB_COMPLETE: 18,
            ORB_ERROR: 12,
        }.get(state, 18)
        self._particles = self._init_particles(count)
        self.update()

    def set_audio_level(self, level: float) -> None:
        self._audio_level = max(0.0, min(1.0, level))

    def sizeHint(self) -> QSize:
        return QSize(self._size, self._size)

    # ---------- painting ----------
    def paintEvent(self, event: QPaintEvent) -> None:
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)

        # background fills whole widget (transparent over parent's black)
        p.fillRect(self.rect(), Qt.GlobalColor.transparent)

        w = self.width()
        h = self.height()
        cx = w / 2
        cy = h / 2
        base_r = min(w, h) / 2

        t = time.perf_counter() - self._start
        period = STATE_PULSE_PERIOD_S.get(self._state, 3.0)
        pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi / period)
        glow = STATE_GLOW.get(self._state, STATE_GLOW[ORB_IDLE])

        self._draw_halo(p, cx, cy, base_r, pulse, glow)
        self._draw_rings(p, cx, cy, base_r, t, period, glow)
        self._draw_particles(p, cx, cy, base_r, t, period, glow)
        self._draw_core(p, cx, cy, base_r, pulse, glow)
        self._draw_highlight(p, cx, cy, base_r)
        if self._state in (ORB_GENERATING, ORB_LISTENING):
            self._draw_waveform(p, cx, cy, base_r, t, glow)
        if self._state == ORB_ERROR:
            self._draw_error_glow(p, cx, cy, base_r, t, glow)

        p.end()

    # ---------- layers ----------
    def _draw_halo(self, p: QPainter, cx: float, cy: float, base_r: float, pulse: float, glow: QColor) -> None:
        halo_r = base_r * (1.05 + 0.05 * pulse)
        grad = QRadialGradient(cx, cy, halo_r)
        c0 = QColor(glow); c0.setAlphaF(0.40 * (0.7 + 0.3 * pulse))
        c1 = QColor(glow); c1.setAlphaF(0.15)
        c2 = QColor(glow); c2.setAlphaF(0.0)
        grad.setColorAt(0.0, c0)
        grad.setColorAt(0.5, c1)
        grad.setColorAt(1.0, c2)
        p.setBrush(QBrush(grad))
        p.setPen(Qt.PenStyle.NoPen)
        p.drawEllipse(QPointF(cx, cy), halo_r, halo_r)

    def _draw_rings(self, p: QPainter, cx: float, cy: float, base_r: float, t: float, period: float, glow: QColor) -> None:
        p.setBrush(Qt.BrushStyle.NoBrush)
        for i in range(3):
            direction = 1 if i % 2 == 0 else -1
            speed = (0.4 + 0.15 * i) / period * direction
            radius = base_r * (0.78 + 0.08 * i)
            arc_len = 0.7 + 0.2 * math.sin(t * 2 + i)
            phase = (t * speed) % (2 * math.pi)
            # dashed stroke via custom path
            import math as _m
            n_dashes = 32
            for j in range(n_dashes):
                a0 = phase + (j / n_dashes) * 2 * _m.pi
                a1 = a0 + (2 * _m.pi / n_dashes) * arc_len
                if a1 - a0 < 1e-3:
                    continue
                alpha = int(220 * (0.5 + 0.5 * math.sin(j * 0.5 + i + t)))
                col = QColor(glow); col.setAlpha(alpha)
                pen = QPen(col, 1.4)
                pen.setCapStyle(Qt.PenCapStyle.RoundCap)
                p.setPen(pen)
                # arc
                from PySide6.QtGui import QPainterPath
                path = QPainterPath()
                x0 = cx + math.cos(a0) * radius
                y0 = cy + math.sin(a0) * radius
                x1 = cx + math.cos(a1) * radius
                y1 = cy + math.sin(a1) * radius
                path.moveTo(x0, y0)
                path.arcTo(QRectF(cx - radius, cy - radius, radius * 2, radius * 2),
                           -_m.degrees(a0), -_m.degrees(a1 - a0))
                p.drawPath(path)

    def _draw_particles(self, p: QPainter, cx: float, cy: float, base_r: float, t: float, period: float, glow: QColor) -> None:
        p.setPen(Qt.PenStyle.NoPen)
        for i, (angle, radius_f, speed) in enumerate(self._particles):
            a = angle + (t / period) * speed * 0.8
            r = base_r * radius_f + 4 * math.sin(t * 1.6 + i)
            x = cx + math.cos(a) * r
            y = cy + math.sin(a) * r
            psize = 1.6 + 2.4 * (0.5 + 0.5 * math.sin(t * 2 + i * 0.7))
            alpha = int(220 * (0.5 + 0.5 * math.sin(t * 2 + i * 0.7)))
            col = QColor(glow); col.setAlpha(alpha)
            p.setBrush(QBrush(col))
            p.drawEllipse(QPointF(x, y), psize, psize)

    def _draw_core(self, p: QPainter, cx: float, cy: float, base_r: float, pulse: float, glow: QColor) -> None:
        scale = 0.55 + 0.04 * pulse
        core_r = base_r * scale
        # gradient: highlight offset to upper-left
        grad = QRadialGradient(cx - core_r * 0.25, cy - core_r * 0.25, core_r)
        c_white = QColor(255, 255, 255, 245)
        c_bright = QColor(NETH_ORANGE_BRIGHT)
        c_orange = QColor(NETH_ORANGE)
        c_deep = QColor(NETH_ORANGE_DEEP)
        c_dark = QColor(0, 0, 0, 230)
        grad.setColorAt(0.0, c_white)
        grad.setColorAt(0.18, c_bright)
        grad.setColorAt(0.45, c_orange)
        grad.setColorAt(0.75, c_deep)
        grad.setColorAt(1.0, c_dark)
        p.setBrush(QBrush(grad))
        p.setPen(Qt.PenStyle.NoPen)
        p.drawEllipse(QPointF(cx, cy), core_r, core_r)

        # rim
        rim_col = QColor(glow); rim_col.setAlphaF(0.25)
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.setPen(QPen(rim_col, 1))
        p.drawEllipse(QPointF(cx, cy), core_r * 0.85, core_r * 0.85)

    def _draw_highlight(self, p: QPainter, cx: float, cy: float, base_r: float) -> None:
        core_r = base_r * 0.55
        hx = cx - core_r * 0.32
        hy = cy - core_r * 0.42
        hw = core_r * 0.5
        hh = core_r * 0.32
        grad = QRadialGradient(hx, hy, hw)
        grad.setColorAt(0.0, QColor(255, 255, 255, 160))
        grad.setColorAt(1.0, QColor(255, 255, 255, 0))
        p.setBrush(QBrush(grad))
        p.setPen(Qt.PenStyle.NoPen)
        p.setCompositionMode(QPainter.CompositionMode.CompositionMode_Plus)
        p.drawEllipse(QPointF(hx, hy), hw, hh)
        p.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceOver)

    def _draw_waveform(self, p: QPainter, cx: float, cy: float, base_r: float, t: float, glow: QColor) -> None:
        bars = 28
        bar_w = 2
        gap = 3
        total_w = bars * (bar_w + gap)
        sx = cx - total_w / 2
        p.setBrush(Qt.BrushStyle.NoBrush)
        col = QColor(glow); col.setAlpha(245)
        pen = QPen(col, bar_w, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap)
        p.setPen(pen)
        amplitude = 1.0 if self._state == ORB_GENERATING else 0.6
        for i in range(bars):
            phase = i / bars
            wave = math.sin(t * 6 + phase * 2 * math.pi * 2)
            env = math.sin(phase * math.pi)
            h = max(2, 8 + 28 * abs(wave) * env * amplitude)
            x = sx + i * (bar_w + gap) + bar_w / 2
            p.drawLine(QPointF(x, cy - h / 2), QPointF(x, cy + h / 2))

    def _draw_error_glow(self, p: QPainter, cx: float, cy: float, base_r: float, t: float, glow: QColor) -> None:
        # subtle warning pulses around the rim
        pulse = 0.5 + 0.5 * math.sin(t * 6)
        col = QColor(NETH_ERROR); col.setAlpha(int(80 + 60 * pulse))
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.setPen(QPen(col, 2))
        p.drawEllipse(QPointF(cx, cy), base_r * 0.95, base_r * 0.95)
