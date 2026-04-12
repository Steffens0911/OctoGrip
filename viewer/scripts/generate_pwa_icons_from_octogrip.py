"""
Gera favicon.png e web/icons/Icon-*.png a partir de assets/branding/octogrip_logo.png.
Fundo sólido #262433 (cartão do login) para o PNG transparente ler bem na barra e no PWA.

Executar na raiz do viewer: python scripts/generate_pwa_icons_from_octogrip.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

CARD_BG = (38, 36, 51, 255)


def _fit_logo(logo: Image.Image, inner: int) -> Image.Image:
    lg = logo.convert("RGBA")
    wr, hr = lg.size
    scale = min(inner / wr, inner / hr)
    nw = max(1, int(wr * scale))
    nh = max(1, int(hr * scale))
    return lg.resize((nw, nh), Image.Resampling.LANCZOS)


def render_icon(logo: Image.Image, size: int, *, maskable: bool) -> Image.Image:
    pad_ratio = 0.22 if maskable else 0.10
    pad = max(2, int(size * pad_ratio))
    inner = size - 2 * pad
    fitted = _fit_logo(logo, inner)
    out = Image.new("RGBA", (size, size), CARD_BG)
    x = pad + (inner - fitted.width) // 2
    y = pad + (inner - fitted.height) // 2
    out.alpha_composite(fitted, (x, y))
    return out


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    logo_path = root / "assets" / "branding" / "octogrip_logo.png"
    if not logo_path.is_file():
        raise SystemExit(f"Missing logo: {logo_path}")

    logo = Image.open(logo_path)
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
        im = render_icon(logo, dim, maskable=mask)
        im.save(out, format="PNG")
        print("Wrote", out.relative_to(root))


if __name__ == "__main__":
    main()
