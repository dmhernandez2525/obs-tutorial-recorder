"""Create icon files for the Tutorial Recorder app."""

from PIL import Image, ImageDraw
from pathlib import Path

def create_icon(size=256):
    """Create a simple video record icon."""
    # Create RGBA image
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background circle (dark gray)
    padding = size // 16
    draw.ellipse(
        [padding, padding, size - padding, size - padding],
        fill=(64, 64, 64, 255),
        outline=(48, 48, 48, 255),
        width=2
    )

    # Inner red record circle
    inner_padding = size // 4
    draw.ellipse(
        [inner_padding, inner_padding, size - inner_padding, size - inner_padding],
        fill=(220, 53, 69, 255),
        outline=(180, 40, 50, 255),
        width=2
    )

    # White center dot
    center_padding = size // 3
    draw.ellipse(
        [center_padding, center_padding, size - center_padding, size - center_padding],
        fill=(255, 255, 255, 200)
    )

    return img

def main():
    resources_dir = Path(__file__).parent / "resources"
    resources_dir.mkdir(exist_ok=True)

    # Create main icon with multiple sizes
    sizes = [16, 32, 48, 64, 128, 256]
    icons = [create_icon(s) for s in sizes]

    # Save as ICO
    ico_path = resources_dir / "icon.ico"
    icons[0].save(
        ico_path,
        format='ICO',
        sizes=[(s, s) for s in sizes],
        append_images=icons[1:]
    )
    print(f"Created: {ico_path}")

    # Create recording state icon (red)
    recording_icons = [create_icon(s) for s in sizes]
    rec_ico_path = resources_dir / "icon_recording.ico"
    recording_icons[0].save(
        rec_ico_path,
        format='ICO',
        sizes=[(s, s) for s in sizes],
        append_images=recording_icons[1:]
    )
    print(f"Created: {rec_ico_path}")

if __name__ == "__main__":
    main()
