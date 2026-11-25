## Generate the juliabridge hex logo (man/figures/logo.svg) and its dark-mode
## version (man/figures/logo-dark.svg).
## Motif: an arch bridge from an R blue bank to one in the three Julia colours,
## with calls crossing the deck from one to the other.
##
## After editing, regenerate the SVGs and re-render the PNG from the package
## root with:
##   Rscript data-raw/logo.R
##   Rscript -e 'rsvg::rsvg_png("man/figures/logo.svg",
##     "man/figures/logo.png", width = 240)'
## Any other SVG renderer (inkscape, rsvg-convert) works as well, though
## ImageMagick's built-in one fails on the wordmark. The wordmark is set in
## Fira Sans, falling back to any sans-serif face.

## standard R hex sticker proportions, pointy top
width <- 1200
height <- width * 2 / sqrt(3)
cx <- width / 2
cy <- height / 2

hexagon <- function(scale = 1) {
  x <- cx + c(0, 1, 1, 0, -1, -1) * width / 2 * scale
  y <- cy + c(-2, -1, 1, 2, 1, -1) / 2 * height / 2 * scale
  paste0("M", paste(sprintf("%.1f,%.1f", x, y), collapse = "L"), "Z")
}

## bridge geometry
deck <- 720
water <- 835
span <- c(250, 950)
rise <- 300
arch_y <- function(x) {
  deck - rise * (1 - ((x - cx) / (diff(span) / 2))^2)
}
arch_x <- seq(span[1], span[2], length.out = 101)
arch <- paste0(
  "M", paste(sprintf("%.1f %.1f", arch_x, arch_y(arch_x)), collapse = " L")
)
hangers <- seq(span[1] + 70, span[2] - 70, by = 70)
pier_w <- 64
bank <- c(175, 1020)

julia <- c("#CB3C33", "#389826", "#9558B2")

## the same design on a light and a dark ground: on the dark one the colours
## are lightened to keep their contrast and the water is darkened so it stays
## in the background
themes <- list(
  light = list(
    file = file.path("man", "figures", "logo.svg"),
    bg_top = "#FFFFFF", bg_bottom = "#E9EFF6", structure = "#33475B",
    water = "#B9CCDE", r = "#276DC3", julia = julia,
    text = "#16283F", accent = "#276DC3"
  ),
  dark = list(
    file = file.path("man", "figures", "logo-dark.svg"),
    bg_top = "#1A2430", bg_bottom = "#131A21", structure = "#C9D4DF",
    water = "#3A4D60", r = "#5C9BE6",
    julia = c("#E5625A", "#5DB84B", "#B57FD0"),
    text = "#F2F5F8", accent = "#6CA8EC"
  )
)

for (theme in themes) {
  ## calls crossing the deck shade from R blue into the Julia colours
  packet_x <- seq(span[1] + 120, span[2] - 120, length.out = 5)
  packet_col <- c(theme$r, theme$r, theme$julia)
  packets <- sprintf(
    '  <circle cx="%.1f" cy="%.1f" r="24" fill="%s"/>',
    packet_x, deck - 44, packet_col
  )

  piers <- sprintf(
    '  <rect x="%.1f" y="%.1f" width="%d" height="%.1f" rx="8" fill="%s"/>',
    span - pier_w / 2, deck - 6, pier_w, water - deck + 30, theme$structure
  )

  ## R on the left bank, the three Julia colours on the right one
  banks <- c(
    sprintf(
      '  <circle cx="%.1f" cy="%.1f" r="58" fill="%s"/>',
      bank[1], deck, theme$r
    ),
    sprintf(
      '  <circle cx="%.1f" cy="%.1f" r="32" fill="%s"/>',
      bank[2] + c(0, -37, 37), deck + c(-32, 32, 32), theme$julia
    )
  )

  ripples <- sprintf(
    paste0(
      '  <path d="M%.1f %.1f q 45 -18 90 0 t 90 0 t 90 0" fill="none"',
      ' stroke="%s" stroke-width="12" stroke-linecap="round"/>'
    ),
    c(300, 640, 470), water + c(0, 0, 50), theme$water
  )

  svg <- c(
    sprintf(
      paste0(
        '<svg xmlns="http://www.w3.org/2000/svg" width="%.0f" height="%.0f" ',
        'viewBox="0 0 %.0f %.0f">'
      ),
      width, height, width, height
    ),
    "  <defs>",
    '    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">',
    sprintf('      <stop offset="0" stop-color="%s"/>', theme$bg_top),
    sprintf('      <stop offset="1" stop-color="%s"/>', theme$bg_bottom),
    "    </linearGradient>",
    "  </defs>",
    sprintf('  <path d="%s" fill="url(#bg)"/>', hexagon()),
    ripples,
    sprintf(
      paste0(
        '  <line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s"',
        ' stroke-width="8" stroke-linecap="round"/>'
      ),
      hangers, arch_y(hangers), hangers, deck, theme$structure
    ),
    sprintf(
      paste0(
        '  <path d="%s" fill="none" stroke="%s" stroke-width="22"',
        ' stroke-linecap="round"/>'
      ),
      arch, theme$structure
    ),
    sprintf(
      paste0(
        '  <line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s"',
        ' stroke-width="22" stroke-linecap="round"/>'
      ),
      bank[1], deck, bank[2] - 37, deck, theme$structure
    ),
    piers,
    packets,
    banks,
    paste0(
      '  <text x="', cx, '" y="', round(height - 300), '" ',
      'text-anchor="middle" font-family="Fira Sans, DejaVu Sans, sans-serif" ',
      'font-weight="600" font-size="140" fill="', theme$text, '">julia',
      '<tspan fill="', theme$accent, '">bridge</tspan></text>'
    ),
    sprintf(
      '  <path d="%s" fill="none" stroke="%s" stroke-width="26"/>',
      hexagon(0.985), theme$accent
    ),
    "</svg>"
  )

  writeLines(svg, theme$file)
}
