"""Rebuild Trivia's original geometric launcher mark (requires Pillow)."""
from pathlib import Path
import json
from PIL import Image, ImageDraw
ROOT = Path(__file__).parent

def icon(size):
    scale = 4
    image = Image.new('RGB', (size * scale, size * scale), '#047857')
    draw = ImageDraw.Draw(image)
    n = size * scale
    # A lowercase t drawn from simple geometry, with a journey-point accent.
    draw.rounded_rectangle((n*.43, n*.23, n*.56, n*.73), radius=n*.065, fill='white')
    draw.rounded_rectangle((n*.28, n*.36, n*.72, n*.48), radius=n*.06, fill='white')
    draw.rounded_rectangle((n*.46, n*.63, n*.67, n*.76), radius=n*.065, fill='white')
    draw.ellipse((n*.66,n*.22,n*.76,n*.32), fill='#10B981')
    return image.resize((size,size), Image.Resampling.LANCZOS)

for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    path = ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'
    path.parent.mkdir(parents=True, exist_ok=True)
    icon(size).save(path)
assets = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
manifest = json.loads((assets / 'Contents.json').read_text())
for entry in manifest['images']:
    if 'filename' in entry:
        size = round(float(entry['size'].split('x')[0]) * float(entry['scale'].rstrip('x')))
        icon(size).save(assets / entry['filename'])
icon(1024).save(ROOT / 'assets/trivia-icon.png')
