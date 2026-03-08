#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_ROOT="$REPO_ROOT/rust/claude-core"
OUTPUT_DIR="$RUST_ROOT/target/release"
BINARY_NAME="claude-core"

TARGETS=(
	"darwin-aarch64"
	"darwin-x86_64"
	"linux-aarch64"
	"linux-x86_64"
)

target_triple() {
	case "$1" in
	darwin-aarch64) echo "aarch64-apple-darwin" ;;
	darwin-x86_64) echo "x86_64-apple-darwin" ;;
	linux-aarch64) echo "aarch64-unknown-linux-gnu" ;;
	linux-x86_64) echo "x86_64-unknown-linux-gnu" ;;
	*) return 1 ;;
	esac
}

if [[ "${1:-}" == "--check-targets" ]]; then
	printf '%s\n' "${TARGETS[@]}"
	exit 0
fi

[[ -d "$RUST_ROOT" ]] || {
	echo "error: missing rust/claude-core at $RUST_ROOT" >&2
	exit 1
}

mkdir -p "$OUTPUT_DIR"

for target in "${TARGETS[@]}"; do
	triple="$(target_triple "$target")"
	echo "==> Building $BINARY_NAME for $target ($triple)"
	cargo build --release --target "$triple" --manifest-path "$RUST_ROOT/Cargo.toml"

	source_bin="$RUST_ROOT/target/$triple/release/$BINARY_NAME"
	[[ -f "$source_bin" ]] || {
		echo "error: expected artifact not found: $source_bin" >&2
		exit 1
	}

	dest_bin="$OUTPUT_DIR/$BINARY_NAME-$target"
	cp "$source_bin" "$dest_bin"
	chmod +x "$dest_bin"
	echo "    wrote $dest_bin"
done

echo "Build complete: artifacts available in $OUTPUT_DIR"
