"""
Gera favicon e ícones PWA para FlowRoll: livro aberto (estudo / aprendizagem),
pictograma simples — âmbar (#D4A017) com fundo transparente (PNG alpha).

Executar na raiz do viewer: python scripts/generate_flowroll_icons.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

GOLD = (212, 160, 23, 255)
# Linhas nas páginas: âmbar mais escuro (não usar “buraco” transparente nas páginas).
GOLD_DIM = (130, 95, 14, 255)
TRANSPARENT = (0, 0, 0, 0)


def _to_px(
    pad: int,
    inner: int,
    ux: float,
    uy: float,
) -> tuple[int, int]:
    return (pad + int(ux * inner), pad + int(uy * inner))


def draw_study_icon(size: int, *, maskable: bool) -> Image.Image:
    """Livro aberto visto de frente; maskable=True = margem extra PWA."""
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    pad = int(size * (0.20 if maskable else 0.10))
    inner = size - 2 * pad

    def tp(ux: float, uy: float) -> tuple[int, int]:
        return _to_px(pad, inner, ux, uy)

    # Páginas abertas (polígonos simétricos).
    left_page = [
        tp(0.20, 0.74),
        tp(0.11, 0.36),
        tp(0.50, 0.16),
        tp(0.50, 0.74),
    ]
    draw.polygon(left_page, fill=GOLD)

    right_page = [
        tp(0.80, 0.74),
        tp(0.89, 0.36),
        tp(0.50, 0.16),
        tp(0.50, 0.74),
    ]
    draw.polygon(right_page, fill=GOLD)

    # Lombada / base entre as páginas.
    spine_h = max(2, inner // 25)
    sx0, sy0 = tp(0.44, 0.72)
    sx1, _ = tp(0.56, 0.72)
    draw.rectangle([sx0, sy0, sx1, sy0 + spine_h], fill=GOLD)

    # Linhas de “texto” sobre as páginas (leitura / estudo).
    line_h = max(2, size // 64)
    for side_sign in (-1, 1):
        base_x = 0.50 + side_sign * 0.17
        for row, y_norm in enumerate((0.34, 0.44, 0.54, 0.64)):
            w = 0.14 - row * 0.015
            cx = base_x + side_sign * 0.02
            x0 = cx - w / 2
            x1 = cx + w / 2
            px0, py = tp(x0, y_norm)
            px1, _ = tp(x1, y_norm)
            draw.rectangle([px0, py, px1, py + line_h], fill=GOLD_DIM)

    # Marcador na lombada (faixa estreita).
    bm_w = max(2, inner // 28)
    mx = size // 2 - bm_w // 2
    my0 = pad + int(inner * 0.10)
    my1 = pad + int(inner * 0.22)
    draw.rectangle([mx, my0, mx + bm_w, my1], fill=GOLD)

    return img


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    web = root / "web"
    branding = root / "assets" / "branding"
    branding.mkdir(parents=True, exist_ok=True)
    icons = web / "icons"
    icons.mkdir(parents=True, exist_ok=True)

    specs = [
        ("favicon.png", 48, False),
        ("icons/Icon-192.png", 192, False),
        ("icons/Icon-512.png", 512, False),
        ("icons/Icon-maskable-192.png", 192, True),
        ("icons/Icon-maskable-512.png", 512, True),
    ]

    for rel, dim, mask in specs:
        out = web / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        im = draw_study_icon(dim, maskable=mask)
        im.save(out, format="PNG")
        print("Wrote", out.relative_to(root))

    app_icon = branding / "flowroll_app_icon.png"
    draw_study_icon(256, maskable=False).save(app_icon, format="PNG")
    print("Wrote", app_icon.relative_to(root))


if __name__ == "__main__":
    main()
