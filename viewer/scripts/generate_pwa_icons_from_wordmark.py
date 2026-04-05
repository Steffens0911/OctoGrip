"""
Gera favicon.png e icons/Icon-*.png a partir de assets/branding/flowroll_wordmark.png
(wordmark Flow Roll — mesma identidade do login). Fundo sólido igual ao cartão do login
(#262433) para a marca branca ler bem na barra do browser e em PWA.

Executar na raiz do viewer: python scripts/generate_pwa_icons_from_wordmark.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

# Cartão do login (`login_screen.dart` _cardBg) — contraste com texto branco da wordmark.
CARD_BG = (38, 36, 51, 255)


def _fit_wordmark(wordmark: Image.Image, inner: int) -> Image.Image:
    wm = wordmark.convert("RGBA")
    wr, hr = wm.size
    scale = min(inner / wr, inner / hr)
    nw = max(1, int(wr * scale))
    nh = max(1, int(hr * scale))
    return wm.resize((nw, nh), Image.Resampling.LANCZOS)


def render_icon(wordmark: Image.Image, size: int, *, maskable: bool) -> Image.Image:
    pad_ratio = 0.22 if maskable else 0.10
    pad = max(2, int(size * pad_ratio))
    inner = size - 2 * pad
    wm = _fit_wordmark(wordmark, inner)
    out = Image.new("RGBA", (size, size), CARD_BG)
    x = pad + (inner - wm.width) // 2
    y = pad + (inner - wm.height) // 2
    out.alpha_composite(wm, (x, y))
    return out


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    wm_path = root / "assets" / "branding" / "flowroll_wordmark.png"
    if not wm_path.is_file():
        raise SystemExit(f"Missing wordmark: {wm_path}")

    wordmark = Image.open(wm_path)
    web = root / "web"
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
        im = render_icon(wordmark, dim, maskable=mask)
        im.save(out, format="PNG")
        print("Wrote", out.relative_to(root))


if __name__ == "__main__":
    main()
