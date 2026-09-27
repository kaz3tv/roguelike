"""16x16 のドット絵素材を文字の絵から PNG に書き出す。

使い方: python3 tools/sprites/make_sprites.py
出力先: assets/art/ （ファイル名は assets/placeholder/ と同じものはそのまま差し替え可能）
Pillow が必要（python3 -m pip install pillow）。
"""
from pathlib import Path
import random

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art"

# 32色パレット。1文字 = 1色、"." は透明。
PALETTE = {
    "k": "#1a1423",  # 輪郭
    "e": "#0d0b12",  # 目
    "x": "#ffffff",  # 白・光
    # 石（壁・床）
    "1": "#241f2e",
    "2": "#2f2a3b",
    "3": "#3d3749",
    "4": "#524a5f",
    "5": "#6b6379",
    "6": "#8a8398",
    # 肌・髪
    "s": "#f2c49b",
    "S": "#c98b6b",
    "b": "#6b3e26",
    # 青（主人公の服）
    "B": "#3d6fb6",
    "n": "#274a80",
    # 緑
    "y": "#a8f08a",
    "G": "#5cc85a",
    "q": "#2f8a3e",
    # 赤
    "r": "#d8404a",
    "R": "#7a1c2a",
    # 金
    "Y": "#f0c848",
    "o": "#b07d28",
    # 紫
    "v": "#b87ae8",
    "p": "#8a4cc8",
    "P": "#542a86",
    # 骨
    "i": "#ece2c6",
    "I": "#a89a7a",
    # 木・革
    "u": "#8a5a34",
    "U": "#5a3820",
    # 金属
    "w": "#e0e4f0",
    "W": "#9aa2b8",
    # 水色
    "c": "#6ed8f0",
}
assert len(PALETTE) <= 32


def to_image(rows, palette=PALETTE):
    assert len(rows) == 16, f"rows={len(rows)}"
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == 16, f"row {y} has {len(row)} chars: {row!r}"
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), hex_to_rgba(palette[ch]))
    return img


def hex_to_rgba(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def bob(rows):
    """歩行2コマ目用：足元の行を残して体を1ドット沈める。"""
    return ["." * 16] + rows[:14] + [rows[15]]


def recolor(rows, mapping):
    return ["".join(mapping.get(c, c) for c in row) for row in rows]


# ---------------------------------------------------------------- タイル

def make_wall(seed):
    rng = random.Random(seed)
    rows = []
    for y in range(16):
        row = ""
        band = y // 4
        offset = 4 if band % 2 else 0
        for x in range(16):
            if y % 4 == 3 or (x + offset) % 8 == 7:
                row += "1"
            elif y % 4 == 0:
                row += "6" if (x + offset) % 8 != 6 else "5"
            elif (x + offset) % 8 == 6 or y % 4 == 2:
                row += "4"
            else:
                row += "5" if rng.random() > 0.12 else "4"
        rows.append(row)
    return rows


def make_floor(seed):
    rng = random.Random(seed)
    rows = []
    for y in range(16):
        row = ""
        for x in range(16):
            if y % 8 == 7 or x % 8 == 7:
                row += "1"
            elif y % 8 == 0 or x % 8 == 0:
                row += "3"
            else:
                row += "2" if rng.random() > 0.1 else "3"
        rows.append(row)
    return rows


def make_corridor(seed):
    rng = random.Random(seed)
    rows = []
    for y in range(16):
        row = ""
        for x in range(16):
            r = rng.random()
            row += "3" if r < 0.08 else ("2" if r < 0.3 else "1")
        rows.append(row)
    # 小石
    for px, py in [(3, 4), (11, 2), (7, 10), (13, 12), (2, 13)]:
        r = list(rows[py])
        r[px] = "4"
        rows[py] = "".join(r)
        r = list(rows[py + 1]) if py + 1 < 16 else None
        if r:
            r[px] = "1"
            rows[py + 1] = "".join(r)
    return rows


STAIRS = [
    "3333333333333331",
    "3kkkkkkkkkkkkkk1",
    "3k666666666666k1",
    "3k444444444444k1",
    "3k1k5555555555k1",
    "3k1k4444444444k1",
    "3k11k555555555k1",
    "3k11k333333333k1",
    "3k111k44444444k1",
    "3k111k22222222k1",
    "3k1111k3333333k1",
    "3k1111k1111111k1",
    "3k11111k222222k1",
    "3k11111kkkkkkkk1",
    "3kkkkkkkkkkkkkk1",
    "1111111111111111",
]

TRAP = [
    "2222222122222221",
    "2333333133333331",
    "2322222122222231",
    "23k1k1k1k1k1k231",
    "231W1W1W1W1W1231",
    "23kwkwkwkwkwk231",
    "2311111111111231",
    "1111111111111111",
    "2311111111111231",
    "23k1k1k1k1k1k231",
    "231W1W1W1W1W1231",
    "23kwkwkwkwkwk231",
    "2311111111111231",
    "2322222122222231",
    "2333333133333331",
    "1111111111111111",
]

# 3階ごとに見た目を変える：1〜3階 石、4〜6階 洞窟（苔）、7〜9階 魔界、10階も魔界
THEMES = {
    "stone": {},
    "cave": {"1": "#1c1a14", "2": "#2a2a1e", "3": "#383826", "4": "#4a5a32",
             "5": "#5f7440", "6": "#83985a"},
    "abyss": {"1": "#1a0e14", "2": "#2a141e", "3": "#3c1c28", "4": "#5a2432",
              "5": "#7a3040", "6": "#a44a50"},
}

# ---------------------------------------------------------------- 主人公

PLAYER_0 = [
    "................",
    ".....kkkkkk.....",
    "....kbbbbbbk....",
    "...kbbbbbbbbk...",
    "...kbssssssbk...",
    ".k.ksesssseskk..",
    "kwk.kssssssk....",
    "kwk..kSSSSk.....",
    "kwk.kBBBBBBkkk..",
    "kwkkBBBnnBBkrrk.",
    "YYYkBBnBBBBkrYrk",
    "kUkksBBBBBBkrrk.",
    ".k.kkYYYYYYkkk..",
    "...knnnkknnnk...",
    "...kUUUkkUUUk...",
    "...kkkk..kkkk...",
]
PLAYER_1 = PLAYER_0[:13] + [
    "...knnnkknnnk...",
    "..kUUUk..kUUUk..",
    "..kkkk....kkkk..",
]

# ---------------------------------------------------------------- 敵

SLIME = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "......kkkk......",
    "....kkyGGGkk....",
    "...kyyGGGGGGk...",
    "..kyGGGGGGGGGk..",
    "..kGGeGGGGeGGk..",
    ".kGGGeGGGGeGGGk.",
    ".kGGGGGGGGGGGqk.",
    ".kqGGGGGGGGGqqk.",
    ".kqqGGGGGGGqqqk.",
    "..kqqqqqqqqqqk..",
    "...kkkkkkkkkk...",
]

BAT_0 = [
    "................",
    "................",
    ".kk..........kk.",
    "kPpk..k..k..kpPk",
    "kPppk.kkkk.kppPk",
    "kPpppkppppkpppPk",
    ".kPpppprrppppPk.",
    ".kPppppppppppPk.",
    "..kPkpkppkpkPk..",
    "..kk.k.kk.k.kk..",
    ".......xx.......",
    "................",
    "................",
    "................",
    "................",
    "................",
]
BAT_1 = [
    "................",
    "................",
    "................",
    "................",
    "......k..k......",
    "......kkkk......",
    "....kkpppPkk....",
    "..kkPpprrppPkk..",
    ".kPpppppppppPPk.",
    "kPppkpppppkppPPk",
    "kPpk.kpppk.kpPPk",
    "kPk...kxxk...kPk",
    "kk............kk",
    "................",
    "................",
    "................",
]

RAT = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "..kk............",
    ".k55k..kkkkk....",
    ".k5kkkk55555k...",
    "kr5555555555k...",
    "k555555555555k..",
    ".kx55555555556kk",
    "..k4444444444k.k",
    "...k6kk6kk6k6k.k",
    "...kk.kk.kk.kk.k",
    "...............k",
]

GOBLIN = [
    "................",
    "................",
    "....k......k....",
    "...kGk.kk.kGk...",
    "...kGGkGGkGGk...",
    "....kGGGGGGk....",
    "....kGrGGrGk....",
    "....kGGGGGGk....",
    ".....kqxxqk.....",
    "..kk.kuuuuk.....",
    "..kWkuuUUuukk...",
    "..kWkGuuuukGk...",
    "..kukkUUUUkk....",
    "....kqqkkqqk....",
    "....kUUkkUUk....",
    "....kkk..kkk....",
]

SKELETON = [
    "................",
    ".....kkkkkk.....",
    "....kiiiiiik....",
    "...kiiiiiiiik...",
    "...kikkiikkik...",
    "...kikkiikkik...",
    "...kiiiIIiiik...",
    "....kikikiik....",
    ".....kkkkkk.....",
    "...kkiiiiiikk.k.",
    "..kik.kiik.kikWk",
    "..kIkiiiiiikkWk.",
    "..kik.kiik.kIk..",
    "......kiik......",
    "....kiik.kiik...",
    "....kkk...kkk...",
]

GHOST = [
    "................",
    ".....kkkkkk.....",
    "....kxxxxxwk....",
    "...kxxxxxxxwk...",
    "..kxxxxxxxxxWk..",
    "..kxxekxxekxWk..",
    "..kxxekxxekxWk..",
    "..kxxxxxxxxxWk..",
    "..kxxxxkkxxwWk..",
    "..kwxxxkkxxwWk..",
    "..kwxxxxxxwwWk..",
    "..kwwxxxxwwWWk..",
    "..kWwwwwwwwWWk..",
    "..kWWkWWWkWWWk..",
    "..kWk.kWk.kWWk..",
    "..kk...k...kk...",
]

MAGE = [
    "......kk........",
    ".....kppk.......",
    ".....kpvpk......",
    "....kppvppk.....",
    "...kpppppppk....",
    "..kkkkkkkkkkk...",
    "....kPeYPeYk.c..",
    "....kPPPPPPkkck.",
    "...kpppppppkkwk.",
    "..kpppYppppkkuk.",
    "..kppppYpppPksk.",
    "..ksppppYppPkuk.",
    "..kkpppppppPkuk.",
    "..kPpppppppPPkuk",
    ".kPPPPPPPPPPPPk.",
    ".kkkkkkkkkkkkk..",
]

ORC = [
    "................",
    "....kkkkkkk.....",
    "...kqqqqqqqk....",
    "..kqGGGGGGGqk...",
    "..kGrGGGGGrGk...",
    "..kGGGGGGGGGk...",
    "..kGxkkkkkxGk...",
    "...kGGGGGGGk....",
    ".kkkUUUUUUUkkk..",
    "kGGkUuuUuuUkGGk.",
    "kGGkUuuUuuUkGGkW",
    "kqqkUUUUUUUkqqkW",
    ".kk.kYYYYYk.kkWW",
    "....kUUkUUk..kuk",
    "...kUUUkUUUk.kuk",
    "...kkkk.kkkk..k.",
]

# ボス（10階）：魔王
BOSS = [
    "..k..........k..",
    ".kYk........kYk.",
    ".kYYk.kkkk.kYYk.",
    "..kYkkRRRRkkYk..",
    "...kRRRRRRRRk...",
    "...kRYeRRYeRk...",
    "...kRRRRRRRRk...",
    "..kkRRkiikRRkk..",
    ".kPPkRRRRRRkPPk.",
    "kPPPPkkkkkkPPPPk",
    "kPpPPPPrrPPPPpPk",
    "kPpPPPrYYrPPPpPk",
    "kPpPPPPrrPPPPpPk",
    "kPpPPPPPPPPPPpPk",
    ".kPPPPPPPPPPPPk.",
    "..kkkkkkkkkkkk..",
]

# ---------------------------------------------------------------- アイテム

POTION = [
    "................",
    "................",
    "......kkkk......",
    "......kuuk......",
    "......kUUk......",
    ".....kwkkwk.....",
    ".....kwxxwk.....",
    "....kwxrrrwk....",
    "...kwxrrrrrwk...",
    "...kwrrrrrrrwk..",
    "...kwrrrrrrrwk..",
    "...kwrrrrrRRwk..",
    "...kwRrrrRRRwk..",
    "....kwRRRRRwk...",
    ".....kkkkkkk....",
    "................",
]

SCROLL = [
    "................",
    "................",
    "..kkkkkkkkkkkk..",
    ".kIiiiiiiiiiiIk.",
    ".kIkkkkkkkkkkIk.",
    "..kiiiiiiiiiik..",
    "..kiIIIiIIIiik..",
    "..kiiiiiiiiiik..",
    "..kiIIiIIIIiik..",
    "..kiiiiiiiiiik..",
    "..kiIIIIiIIiik..",
    "..kiiiiiiiiiik..",
    ".kIkkkkkkkkkkIk.",
    ".kIiiiiiiiiiiIk.",
    "..kkkkkkkkkkkk..",
    "................",
]

SWORD = [
    "................",
    ".............kk.",
    "............kxwk",
    "...........kxwk.",
    "..........kxwk..",
    ".........kxwk...",
    "........kxwk....",
    ".......kxwk.....",
    "..kk..kxwk......",
    "..kYkkxwk.......",
    "...kYkwk........",
    "....kYk.........",
    "...kUkYk........",
    "..kUk.kYk.......",
    ".kok...kk.......",
    "..k.............",
]

SHIELD = [
    "................",
    "..kkkkkkkkkkkk..",
    "..kWwwwwwwwwWk..",
    "..kwBBBBYBBBWk..",
    "..kwBBBBYBBBWk..",
    "..kwBBBBYBBBWk..",
    "..kwYYYYYYYYWk..",
    "..kwBBBBYBBnWk..",
    "..kwBBBBYBBnWk..",
    "...kwBBBYBnWk...",
    "...kWBBBYnnWk...",
    "....kWBBYnWk....",
    ".....kWnYWk.....",
    "......kWWk......",
    ".......kk.......",
    "................",
]


def main():
    out = {}
    # タイル：1〜3階（placeholder と同じ名前）
    tiles = {
        "wall": make_wall(1),
        "floor": make_floor(2),
        "corridor": make_corridor(3),
        "stairs": STAIRS,
        "trap": TRAP,
    }
    for theme, colors in THEMES.items():
        palette = dict(PALETTE, **colors)
        for name, rows in tiles.items():
            key = f"{name}.png" if theme == "stone" else f"tiles_{theme}/{name}.png"
            out[key] = to_image(rows, palette)

    out["player_0.png"] = to_image(PLAYER_0)
    out["player_1.png"] = to_image(PLAYER_1)

    enemies = {
        "slime": (SLIME, bob(SLIME)),
        "bat": (BAT_0, BAT_1),
        "rat": (RAT, bob(RAT)),
        "goblin": (GOBLIN, bob(GOBLIN)),
        "skeleton": (SKELETON, bob(SKELETON)),
        "ghost": (GHOST, ["." * 16] + GHOST[:15]),
        "mage": (MAGE, bob(MAGE)),
        "orc": (ORC, bob(ORC)),
        "boss": (BOSS, bob(BOSS)),
    }
    for name, (f0, f1) in enemies.items():
        out[f"enemies/{name}_0.png"] = to_image(f0)
        out[f"enemies/{name}_1.png"] = to_image(f1)

    for name, rows in {"potion": POTION, "scroll": SCROLL, "sword": SWORD,
                       "shield": SHIELD}.items():
        out[f"items/{name}.png"] = to_image(rows)

    for rel, img in out.items():
        path = OUT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
    print(f"{len(out)} files -> {OUT}")
    return out


if __name__ == "__main__":
    main()
