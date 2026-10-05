"""Draw the Workshop cover without using game or third-party artwork."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


HERE = Path(__file__).resolve().parent
SCALE = 3
SIZE = 512
W = H = SIZE * SCALE
FONT_DIR = Path("C:/Windows/Fonts")


def s(value):
    return round(value * SCALE)


def box(*values):
    return tuple(s(value) for value in values)


def font(name, size):
    return ImageFont.truetype(str(FONT_DIR / name), s(size))


def centered(draw, text, y, chosen_font, fill):
    left, top, right, bottom = draw.textbbox((0, 0), text, font=chosen_font)
    draw.text(((W - (right - left)) / 2, s(y) - top), text, font=chosen_font, fill=fill)


canvas = Image.new("RGBA", (W, H), "#0b1420")

# A soft cyan and amber field makes the single slot readable at thumbnail size.
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
g = ImageDraw.Draw(glow)
g.ellipse(box(68, 35, 464, 410), fill=(35, 232, 226, 85))
g.ellipse(box(182, 150, 444, 396), fill=(255, 176, 65, 105))
canvas = Image.alpha_composite(canvas, glow.filter(ImageFilter.GaussianBlur(s(72))))
d = ImageDraw.Draw(canvas)

# Fine background grid, kept behind the central icon.
for x in range(-260, 800, 52):
    d.line((s(x), 0, s(x + 260), H), fill=(82, 145, 164, 12), width=s(1))
for y in range(30, 500, 52):
    d.line((0, s(y), W, s(y)), fill=(82, 145, 164, 10), width=s(1))

d.rounded_rectangle(box(31, 27, 480, 502), radius=s(38), fill="#121f2b", outline="#35515d", width=s(2))
d.rounded_rectangle(box(44, 40, 467, 489), radius=s(31), outline="#203743", width=s(1))

# Header label and one-slot counter.
d.rounded_rectangle(box(61, 59, 194, 84), radius=s(12), fill="#163d45", outline="#298a91", width=s(1))
d.text(box(75, 63), "CREATOR LIBRARY", font=font("arialbd.ttf", 10), fill="#85f4ee")
d.text(box(395, 62), "01 / 01", font=font("bahnschrift.ttf", 12), fill="#b9d7dc")

# Outer slot and inset. The motif is an original geometric ability symbol.
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sh = ImageDraw.Draw(shadow)
sh.rounded_rectangle(box(108, 101, 404, 389), radius=s(58), fill=(32, 243, 231, 140), width=s(2))
canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(s(28))))
d = ImageDraw.Draw(canvas)
d.rounded_rectangle(box(105, 98, 407, 393), radius=s(57), fill="#122732", outline="#4ee3de", width=s(4))
d.rounded_rectangle(box(119, 112, 393, 379), radius=s(45), fill="#0d1b28", outline="#42616c", width=s(2))
d.arc(box(146, 138, 366, 358), start=207, end=333, fill="#5be7e0", width=s(5))
d.arc(box(158, 150, 354, 346), start=25, end=154, fill="#be8e52", width=s(5))

# Diamond-shaped item crystal, with a lightning-shaped opening.
crystal = [(256, 153), (328, 225), (307, 293), (256, 335), (205, 293), (184, 225)]
d.polygon([(s(x), s(y)) for x, y in crystal], fill="#e4a356")
d.line([(s(x), s(y)) for x, y in crystal + [crystal[0]]], fill="#ffe2a8", width=s(5), joint="curve")
d.polygon([(s(256), s(153)), (s(328), s(225)), (s(256), s(243))], fill="#ffc373")
d.polygon([(s(256), s(243)), (s(307), s(293)), (s(256), s(335))], fill="#b87138")
d.polygon([(s(184), s(225)), (s(256), s(153)), (s(256), s(243))], fill="#f3b466")
d.polygon([(s(239), s(192)), (s(271), s(192)), (s(251), s(237)), (s(277), s(237)), (s(235), s(298)), (s(245), s(252)), (s(221), s(252))], fill="#fff0c2")

# Small Q key attached to the slot conveys the default action key.
d.rounded_rectangle(box(334, 315, 410, 391), radius=s(22), fill="#1e444a", outline="#72f7ec", width=s(4))
d.rounded_rectangle(box(343, 324, 401, 382), radius=s(16), outline="#3f8588", width=s(2))
centered_q = font("arialbd.ttf", 35)
q_box = d.textbbox((0, 0), "Q", font=centered_q)
d.text((s(372) - (q_box[2] - q_box[0]) / 2, s(353) - (q_box[3] - q_box[1]) / 2 - q_box[1]), "Q", font=centered_q, fill="#e4fffb")

# Title and Chinese subtitle are fully legible at the required 512 px size.
centered(d, "ACTIVE ITEM", 401, font("arialbd.ttf", 39), "#f4f8f4")
centered(d, "LIBRARY", 442, font("arialbd.ttf", 35), "#67ede5")
centered(d, "主动道具前置库", 480, font("msyhbd.ttc", 17), "#a1b8be")

canvas = canvas.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
output = HERE / "preview.png"
canvas.save(output, format="PNG", optimize=True)
print(f"{output}: {output.stat().st_size} bytes")
