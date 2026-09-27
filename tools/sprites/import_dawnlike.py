"""DawnLike（16x16 のローグライク用素材集）から、ゲームで使う絵を切り出して assets/art/ に書き出す。

使い方:
    git clone https://github.com/hadean-mirrors/dawnlike /tmp/dawnlike
    python3 tools/sprites/import_dawnlike.py /tmp/dawnlike

DawnLike は DragonDePlatino 作、パレットは DawnBringer（CC-BY 4.0）。クレジットは assets/art/CREDITS.md。
Pillow が必要（python3 -m pip install pillow）。
"""
from pathlib import Path
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art"
T = 16

# 3階ごとのテーマ。floor / wall は DawnLike の自動タイル1組の左上の位置（タイル単位）。
# 床はその組の中央 (+1, +1)、壁は横につながる部分 (+3, +0) を使う。
THEMES = {
    "": {"floor": (0, 9), "wall": (0, 9)},  # 1〜3階：石の床と青い石壁
    "tiles_cave/": {"floor": (0, 21), "wall": (0, 18)},  # 4〜6階：土の床と岩壁
    "tiles_abyss/": {"floor": (7, 24), "wall": (14, 12)},  # 7〜10階：赤れんがと溶岩の壁
}
CORRIDOR = (0, 24)  # 通路：暗い土
STAIRS = ("Objects/Tile.png", 5, 3)
TRAP = ("Objects/Trap1.png", 1, 3)

# キャラは <名前>0.png と <名前>1.png が2コマのアニメになっている
PLAYER = ("Characters/Player", 1, 3)
ENEMIES = {
    "slime": ("Characters/Slime", 0, 3),
    "bat": ("Characters/Avian", 0, 1),
    "rat": ("Characters/Rodent", 0, 1),
    "goblin": ("Characters/Player", 0, 14),
    "skeleton": ("Characters/Undead", 0, 2),
    "ghost": ("Characters/Undead", 0, 4),
    "mage": ("Characters/Humanoid", 1, 10),
    "orc": ("Characters/Player", 0, 12),
    "boss": ("Characters/Demon", 3, 1),
}
ITEMS = {
    "potion": ("Items/Potion.png", 0, 0),
    "scroll": ("Items/Scroll.png", 0, 0),
    "sword": ("Items/MedWep.png", 0, 0),
    "shield": ("Items/Shield.png", 0, 0),
}


def main(src):
    src = Path(src)
    cache = {}

    def tile(rel, x, y):
        if rel not in cache:
            cache[rel] = Image.open(src / rel).convert("RGBA")
        return cache[rel].crop((x * T, y * T, x * T + T, y * T + T))

    def on(base, top):
        img = base.copy()
        img.alpha_composite(top)
        return img

    out = {}
    corridor = tile("Objects/Floor.png", CORRIDOR[0] + 1, CORRIDOR[1] + 1)
    for prefix, theme in THEMES.items():
        fx, fy = theme["floor"]
        wx, wy = theme["wall"]
        floor = tile("Objects/Floor.png", fx + 1, fy + 1)
        out[prefix + "floor.png"] = floor
        out[prefix + "wall.png"] = tile("Objects/Wall.png", wx + 3, wy)
        out[prefix + "corridor.png"] = corridor
        out[prefix + "stairs.png"] = on(floor, tile(*STAIRS))
        out[prefix + "trap.png"] = on(floor, tile(*TRAP))

    for frame in (0, 1):
        name, x, y = PLAYER
        out[f"player_{frame}.png"] = tile(f"{name}{frame}.png", x, y)
        for enemy, (name, x, y) in ENEMIES.items():
            out[f"enemies/{enemy}_{frame}.png"] = tile(f"{name}{frame}.png", x, y)

    for item, spec in ITEMS.items():
        out[f"items/{item}.png"] = tile(*spec)

    for rel, img in out.items():
        path = OUT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
    print(f"{len(out)} files -> {OUT}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
