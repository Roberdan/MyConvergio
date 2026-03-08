#!/bin/bash
# compile-report.sh - Compile LaTeX report to PDF
# Usage: compile-report.sh <tex_file> [output_dir]

set -euo pipefail

TEX_FILE="${1:-}"
OUTPUT_DIR="${2:-./output}"

if [[ -z "$TEX_FILE" ]]; then
	echo "Usage: compile-report.sh <tex_file> [output_dir]"
	exit 1
fi

if [[ ! -f "$TEX_FILE" ]]; then
	echo "Error: File not found: $TEX_FILE"
	exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Get filename without extension
BASENAME=$(basename "$TEX_FILE" .tex)

echo "Compiling $TEX_FILE..."

# First pass
xelatex -output-directory="$OUTPUT_DIR" -interaction=nonstopmode "$TEX_FILE" || {
	echo "First pass completed with warnings"
}

# Check if bibliography exists
if grep -q "\\\\bibliography{" "$TEX_FILE" 2>/dev/null; then
	echo "Processing bibliography..."
	cd "$OUTPUT_DIR"
	biber "$BASENAME" 2>/dev/null || bibtex "$BASENAME" 2>/dev/null || true
	cd - >/dev/null
fi

# Second pass for references
xelatex -output-directory="$OUTPUT_DIR" -interaction=nonstopmode "$TEX_FILE" || {
	echo "Second pass completed with warnings"
}

# Final pass for table of contents
xelatex -output-directory="$OUTPUT_DIR" -interaction=nonstopmode "$TEX_FILE" || {
	echo "Final pass completed with warnings"
}

# Clean up auxiliary files
echo "Cleaning up auxiliary files..."
cd "$OUTPUT_DIR"
rm -f *.aux *.log *.out *.toc *.bbl *.blg *.bcf *.run.xml 2>/dev/null || true
cd - >/dev/null

# Clean up source files (keep only final PDF)
echo "Cleaning up source files..."
cd "$OUTPUT_DIR"
rm -f *.tex compile.sh sources.bib 2>/dev/null || true
rm -rf sections/ tables/ 2>/dev/null || true
cd - >/dev/null

PDF_FILE="$OUTPUT_DIR/$BASENAME.pdf"
if [[ -f "$PDF_FILE" ]]; then
	echo "✓ PDF generated: $PDF_FILE"
	echo "  Size: $(du -h "$PDF_FILE" | cut -f1)"
else
	echo "✗ PDF generation failed"
	exit 1
fi
