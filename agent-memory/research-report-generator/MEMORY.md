# Research Report Generator Memory

## LaTeX Patterns (XeLaTeX on macOS)

- `\raise` does NOT work inside tabularx X/L/R/C paragraph-mode columns. Use `\textasciitilde` via a `\newcommand{\tildex}{\textasciitilde}` macro instead of `{\raise.17ex\hbox{$\scriptstyle\sim$}}`.
- `tabularx` inside `tcolorbox` can cause `\cr` errors. Use regular `tabular` with fixed `p{}` widths inside tcolorbox.
- XeLaTeX path on this system: `/Library/TeX/texbin/xelatex` (TeX Live 2025).
- Font available: Helvetica Neue (with Bold/Italic variants), Menlo for monospace.
- Always compile twice for `lastpage` cross-references.
- Remove forced `\newpage` between sections for denser output. Let LaTeX float tables naturally.
- Morgan Stanley color palette: msblue=#003366, mslightblue=#0066CC, msred=#CC3333, msgreen=#2D8C3C, coverblue=#001A33.
- Cover page blue band: use tikz overlay fill, ~11.5cm from top works well for 2-line title.

## User Preferences

- Output is PDF only. Clean up .aux/.log/.out after compilation.
- Keep .tex source file alongside PDF (not deleted).
- Professional equity research / consulting style (Morgan Stanley / McKinsey aesthetic).
- Language: conversation in Italian or English; code/docs always English.
