import random
from pathlib import Path
from PIL import Image, ImageDraw

ASSETS_DIR = Path(__file__).resolve().parents[1] / 'assets'
random.seed(7)
SIZE = (256, 256)

def noisy_base(base, spread):
    img = Image.new('RGB', SIZE)
    px = img.load()
    for x in range(SIZE[0]):
        for y in range(SIZE[1]):
            n = random.randint(-spread, spread)
            px[x, y] = tuple(max(0, min(255, c + n)) for c in base)
    return img

def add_cracks(d, count, color):
    for _ in range(count):
        x, y = random.randint(0, 255), random.randint(0, 255)
        for _ in range(20):
            nx = x + random.randint(-3, 3)
            ny = y + random.randint(1, 4)
            d.line([(x, y), (nx, ny)], fill=color, width=1)
            x, y = nx, ny

# ---- WALL: dark yellow stone panels ----
wall = noisy_base((150, 130, 60), 12)
d = ImageDraw.Draw(wall)
for x in (0, 128):
    d.line([(x, 0), (x, 255)], fill=(60, 50, 25), width=4)
for y in (0, 128):
    d.line([(0, y), (255, y)], fill=(60, 50, 25), width=4)
add_cracks(d, 6, (40, 35, 20))
for y in range(190, 256):          # dark grime at the bottom
    t = (y - 190) / 66
    d.line([(0, y), (255, y)], fill=(int(120 - 70 * t), int(105 - 60 * t), int(45 - 30 * t)))
wall.save(ASSETS_DIR / 'wall.png')

# ---- FLOOR: dark brown tiles ----
floor = noisy_base((70, 60, 30), 10)
d = ImageDraw.Draw(floor)
for x in (0, 128):
    d.line([(x, 0), (x, 255)], fill=(35, 30, 15), width=3)
for y in (0, 128):
    d.line([(0, y), (255, y)], fill=(35, 30, 15), width=3)
add_cracks(d, 4, (25, 22, 10))
floor.save(ASSETS_DIR / 'floor.png')

print("assets/wall.png and assets/floor.png created")