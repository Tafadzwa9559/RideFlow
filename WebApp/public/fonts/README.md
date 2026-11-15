# Trivia fonts

Self-hosted Latin variable WOFF2 subsets from Google Fonts, downloaded 2026-11-13.

- Inter (400–800): https://fonts.google.com/specimen/Inter
- Plus Jakarta Sans (600–800): https://fonts.google.com/specimen/Plus+Jakarta+Sans

Both use the SIL Open Font License; the respective OFL files are included here.
The Latin subsets cover the current English content; other characters use system fallbacks.
Only these two compressed files are preloaded, with `font-display: swap` so text remains visible.

The authoritative scale and semantic tokens live in `src/typography.css`.
Public headings use Plus Jakarta Sans, with Inter for body text and controls.
Administration uses Inter throughout. Tiny text inside the illustrative product mockup
is deliberately separate from the website's readable typography scale.
