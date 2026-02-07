#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


@dataclass(frozen=True)
class AppIconSpec:
    size_pt: int
    scale: int
    filename: str

    @property
    def pixel_size(self) -> int:
        return self.size_pt * self.scale


SPECS: list[AppIconSpec] = [
    AppIconSpec(16, 1, "icon_16x16.png"),
    AppIconSpec(16, 2, "icon_16x16@2x.png"),
    AppIconSpec(32, 1, "icon_32x32.png"),
    AppIconSpec(32, 2, "icon_32x32@2x.png"),
    AppIconSpec(128, 1, "icon_128x128.png"),
    AppIconSpec(128, 2, "icon_128x128@2x.png"),
    AppIconSpec(256, 1, "icon_256x256.png"),
    AppIconSpec(256, 2, "icon_256x256@2x.png"),
    AppIconSpec(512, 1, "icon_512x512.png"),
    AppIconSpec(512, 2, "icon_512x512@2x.png"),
]


def make_diagonal_gradient(size: int, start: tuple[int, int, int], end: tuple[int, int, int]) -> Image.Image:
    mask = Image.linear_gradient("L").resize((size, size)).rotate(45, resample=Image.BICUBIC)
    bg1 = Image.new("RGBA", (size, size), start + (255,))
    bg2 = Image.new("RGBA", (size, size), end + (255,))
    return Image.composite(bg2, bg1, mask)


def make_background(size: int) -> Image.Image:
    bg = make_diagonal_gradient(size, start=(20, 109, 255), end=(0, 229, 168))

    padding = int(size * 0.07)
    radius = int(size * 0.23)

    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        (padding, padding, size - padding, size - padding),
        radius=radius,
        fill=255,
    )
    bg.putalpha(mask)

    border = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border)
    border_draw.rounded_rectangle(
        (padding, padding, size - padding, size - padding),
        radius=radius,
        outline=(255, 255, 255, 48),
        width=max(2, size // 256),
    )

    bg.alpha_composite(border)
    return bg


def make_q_mark(size: int) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    cx = cy = size // 2
    outer_r = int(size * 0.31)
    inner_r = int(size * 0.19)

    draw.ellipse((cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r), fill=(255, 255, 255, 255))
    draw.ellipse((cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r), fill=(0, 0, 0, 0))

    tail_w = int(size * 0.30)
    tail_h = int(size * 0.10)
    tail = Image.new("RGBA", (tail_w, tail_h), (0, 0, 0, 0))
    tail_draw = ImageDraw.Draw(tail)
    tail_draw.rounded_rectangle((0, 0, tail_w, tail_h), radius=tail_h // 2, fill=(255, 255, 255, 255))
    tail_rot = tail.rotate(-35, resample=Image.BICUBIC, expand=True)

    tail_cx = cx + int(outer_r * 0.55)
    tail_cy = cy + int(outer_r * 0.60)
    layer.alpha_composite(tail_rot, (tail_cx - tail_rot.width // 2, tail_cy - tail_rot.height // 2))

    return layer


def composite_icon(size: int) -> Image.Image:
    bg = make_background(size)
    q = make_q_mark(size)

    q_alpha = q.getchannel("A")
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 140))
    shadow.putalpha(q_alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(2, size // 48)))

    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.alpha_composite(bg)
    icon.alpha_composite(shadow, (0, max(2, size // 40)))
    icon.alpha_composite(q)
    return icon


def write_icons(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    master_size = max(spec.pixel_size for spec in SPECS)
    master = composite_icon(master_size)

    for spec in SPECS:
        img = master.resize((spec.pixel_size, spec.pixel_size), resample=Image.LANCZOS)
        img.save(out_dir / spec.filename, format="PNG", optimize=True)


def main() -> None:
    repo_root = Path(__file__).resolve().parents[2]
    default_out = repo_root / "quicker" / "Assets.xcassets" / "AppIcon.appiconset"
    write_icons(default_out)
    print(f"Wrote {len(SPECS)} files to {default_out}")


if __name__ == "__main__":
    main()

