"""Generates the app icon.

Why a script: icon files are binary and cannot be reviewed. Keeping the source
here gives colour and shape a single point of truth for the day they need to
change -- run this instead of editing the PNGs by hand.

    python tool/generate_icons.py

Shape: a cream card on a terracotta ground, with a second, slightly tilted card
behind it. The two short strokes on the card mean "something has been written
on it". The tone matches the app: calm, unadorned, one point of emphasis.
"""

from PIL import Image, ImageDraw

# Exactly the same values as tokens.dart.
TERRACOTTA = (184, 104, 75, 255)  # AppPalette.accent
CREAM = (250, 250, 249, 255)  # AppPalette.light.background

# Legacy (pre-adaptive) icon sizes.
LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# The adaptive icon foreground is 108dp; the safe area is the middle 72dp.
ADAPTIVE = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

RES = "android/app/src/main/res"

# 4x supersampling: at small sizes the rotated edges would otherwise come out
# jagged.
SS = 4


def draw_cards(size: int, scale: float, card_color, line_color, bg=None):
    """Draws the card mark. [scale] is the mark's ratio to the canvas."""
    canvas = size * SS
    img = Image.new("RGBA", (canvas, canvas), bg or (0, 0, 0, 0))

    w = int(canvas * 0.40 * scale)
    h = int(canvas * 0.54 * scale)
    r = int(canvas * 0.05 * scale)
    cx, cy = canvas // 2, canvas // 2

    def card(fill, angle, dx, dy):
        # Drawn on a separate layer and rotated: PIL cannot draw a rotated
        # rectangle directly.
        layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        ImageDraw.Draw(layer).rounded_rectangle(
            [cx - w // 2 + dx, cy - h // 2 + dy, cx + w // 2 + dx, cy + h // 2 + dy],
            radius=r,
            fill=fill,
        )
        return layer.rotate(angle, resample=Image.BICUBIC, center=(cx, cy))

    # The card behind: a sense of depth. Faded, because the front card is the subject.
    faded = (card_color[0], card_color[1], card_color[2], 110)
    img.alpha_composite(card(faded, -14, -int(w * 0.14), 0))
    img.alpha_composite(card(card_color, 0, 0, 0))

    # Two short lines on the front card -- "something written".
    draw = ImageDraw.Draw(img)
    line_w = int(w * 0.52)
    line_h = max(2, int(h * 0.055))
    gap = int(h * 0.13)
    top = cy - int(h * 0.10)
    for i, width in enumerate([line_w, int(line_w * 0.62)]):
        y = top + i * gap
        draw.rounded_rectangle(
            [cx - line_w // 2, y, cx - line_w // 2 + width, y + line_h],
            radius=line_h // 2,
            fill=line_color,
        )

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    for folder, size in LEGACY.items():
        # In the legacy icon the ground is part of the image: rounding is the system's job.
        icon = draw_cards(size, scale=1.0, card_color=CREAM,
                          line_color=TERRACOTTA, bg=TERRACOTTA)
        icon.save(f"{RES}/{folder}/ic_launcher.png")

    for folder, size in ADAPTIVE.items():
        # The foreground has to stay inside the safe area: launchers crop the edges.
        # 0.72: at 0.62 the mark looks small inside the launcher mask. The
        # safe area is 72/108 = 0.67; the card itself sits inside it, and the
        # tilted card behind spills a few pixels over the edge -- harmless,
        # since it is faded anyway.
        fg = draw_cards(size, scale=0.72, card_color=CREAM,
                        line_color=TERRACOTTA)
        fg.save(f"{RES}/{folder}/ic_launcher_foreground.png")

        # The Android 13 themed icon: a single-colour silhouette. The system
        # applies its own colour, so it is drawn in white and the lines leave gaps.
        mono = draw_cards(size, scale=0.72, card_color=(255, 255, 255, 255),
                          line_color=(0, 0, 0, 0))
        mono.save(f"{RES}/{folder}/ic_launcher_monochrome.png")

    print("icons generated")


if __name__ == "__main__":
    main()
