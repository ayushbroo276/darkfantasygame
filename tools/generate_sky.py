from pathlib import Path

from PIL import Image

ASSETS_DIR = Path(__file__).resolve().parents[1] / 'assets'

w, h = 2048, 1024
img = Image.new('RGB', (w, h))
px = img.load()

top = (10, 5, 20)       # dark purple at the top
bottom = (90, 25, 20)   # dark red near the horizon

for y in range(h):
    t = y / h
    color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
    for x in range(w):
        px[x, y] = color

output_path = ASSETS_DIR / 'sky.png'
img.save(output_path)
print(f'{output_path} created')