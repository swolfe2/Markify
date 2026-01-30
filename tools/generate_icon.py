"""
Generate Multi-Size ICO File for Windows Taskbar Compatibility

This script creates a proper Windows ICO file with multiple sizes
required for consistent taskbar and window icon display:
- 16x16 (small icons, file explorer)
- 32x32 (standard taskbar)
- 48x48 (large taskbar)
- 256x256 (high DPI, Windows 10/11 scaling)

Usage:
    python tools/generate_icon.py

Requires: Pillow (pip install Pillow)
"""

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow is required. Install with: pip install Pillow")
    sys.exit(1)


def generate_multi_size_ico(
    source_png: Path,
    output_ico: Path,
    sizes: tuple[int, ...] = (16, 32, 48, 256),
) -> None:
    """Generate a multi-size ICO file from a PNG source."""

    # Load source image
    if not source_png.exists():
        raise FileNotFoundError(f"Source PNG not found: {source_png}")

    source = Image.open(source_png)

    # Ensure we have RGBA mode for transparency
    if source.mode != "RGBA":
        source = source.convert("RGBA")

    # Generate images at each required size
    images = []
    for size in sizes:
        # Use LANCZOS for high-quality downscaling
        resized = source.resize((size, size), Image.Resampling.LANCZOS)
        images.append(resized)

    # Save as ICO with all sizes
    # Pillow's ICO plugin requires we save the largest image first,
    # then append smaller ones. We also need to pass the exact sizes.
    images_reversed = list(reversed(images))  # 256, 48, 32, 16
    sizes_reversed = list(reversed(sizes))

    images_reversed[0].save(
        output_ico,
        format="ICO",
        sizes=[(s, s) for s in sizes_reversed],
        append_images=images_reversed[1:],
    )

    print(f"[OK] Generated ICO with sizes: {sizes}")
    print(f"  Output: {output_ico}")

    # Verify the result
    verify_ico(output_ico)


def verify_ico(ico_path: Path) -> None:
    """Verify the ICO file contains expected sizes."""
    img = Image.open(ico_path)
    sizes = img.info.get("sizes", set())
    print(f"  Verified sizes in ICO: {sizes}")


def main():
    # Determine paths relative to project root
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    resources_dir = project_root / "resources"

    source_png = resources_dir / "markify_icon.png"
    output_ico = resources_dir / "markify_icon.ico"

    # Backup existing ICO if present
    if output_ico.exists():
        backup_path = resources_dir / "archive" / "markify_icon_backup.ico"
        backup_path.parent.mkdir(exist_ok=True)
        import shutil
        shutil.copy2(output_ico, backup_path)
        print(f"  Backed up existing ICO to: {backup_path}")

    generate_multi_size_ico(source_png, output_ico)
    print("\n[OK] Icon generation complete!")


if __name__ == "__main__":
    main()
