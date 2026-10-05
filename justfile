# Reduce an image to at most 2MB (or a custom SIZE) by re-encoding as JPEG.
# Requires ImageMagick (`convert`).
#
# Usage:
#   just compress hand.JPG
#   just compress hand.JPG 500KB
compress file size="2MB":
    #!/usr/bin/env bash
    set -euo pipefail
    out="{{without_extension(file)}}-compressed.jpg"
    convert "{{file}}" -strip -define jpeg:extent={{size}} "$out"
    echo "Wrote $out ($(du -h "$out" | cut -f1))"

# Print an image borderless (full-bleed) on the Canon SELPHY CP1500.
# size is one of the PPD's page sizes: Postcard (default), 89x119mm, 54x86mm.
#
# Usage:
#   just print hand.JPG
#   just print hand.JPG 89x119mm
printer := "Canon_SELPHY_CP1500_USB"

print file size="Postcard":
    lp -d {{printer}} -o media={{size}}.Borderless -o print-scaling=fill "{{file}}"
