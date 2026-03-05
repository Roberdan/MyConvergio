#!/usr/bin/env bash
set -euo pipefail
# Error Digest - Parse stack traces into compact JSON
# Strips node_modules frames, extracts error type + file:line.
# Usage: some-command 2>&1 | error-digest.sh
#   Or: error-digest.sh < logfile.txt
#   Or: error-digest.sh --run "npm test"  (captures and parses)
# Version: 1.1.0
set -euo pipefail

MODE="stdin"
CMD=""
if [[ "${1:-}" == "--run" ]]; then
	MODE="run"
	CMD="${2:?Usage: error-digest.sh --run \"command\"}"
fi

TMPLOG=$(mktemp)
trap "rm -f '$TMPLOG'" EXIT INT TERM

if [[ "$MODE" == "run" ]]; then
	read -ra CMD_ARGS <<<"$CMD"
	"${CMD_ARGS[@]}" >"$TMPLOG" 2>&1 || true
else
	cat >"$TMPLOG"
fi

[[ ! -s "$TMPLOG" ]] && {
	jq -n '{"errors":[],"count":0}'
	exit 0
}

# Parse Node.js/TypeScript style errors
# Pattern: ErrorType: message\n    at function (file:line:col)
NODE_ERRORS=$(perl -0777 -ne '
	my @errors;
	# Match Error: message followed by at-stack lines
	while (/^(\w*Error\w*:\s*.+?)(?=\n(?!\s+at\s)|\z)/msg) {
		my $block = $1;
		my ($type, $msg) = $block =~ /^(\w+Error\w*):\s*(.+)/;
		$msg //= $block;
		$msg = substr($msg, 0, 200);

		# Find first non-node_modules frame
		my ($file, $line) = ("", "");
		while ($block =~ /at\s+\S+\s+\(([^)]+)\)/g) {
			my $loc = $1;
			next if $loc =~ /node_modules/;
			($file, $line) = $loc =~ /(.+?):(\d+)/;
			last;
		}
		$file //= "";
		$line //= "";
		$type //= "Error";

		# Escape for JSON (backslashes first, then quotes)
		$msg =~ s/\\/\\\\/g;
		$msg =~ s/"/\\"/g;
		$file =~ s/\\/\\\\/g;
		$file =~ s/"/\\"/g;
		push @errors, sprintf("{\"type\":\"%s\",\"msg\":\"%s\",\"file\":\"%s\",\"line\":%s}",
			$type, $msg, $file, $line || "null");
	}
	print "[" . join(",", @errors) . "]" if @errors;
' "$TMPLOG" 2>/dev/null)

# Fallback: grep for error-like lines if perl found nothing
if [[ -z "$NODE_ERRORS" || "$NODE_ERRORS" == "[]" ]]; then
	NODE_ERRORS=$(grep -inE '(Error|FAIL|FATAL|Uncaught|Unhandled|ENOENT|EPERM|EACCES|TypeError|ReferenceError|SyntaxError):' "$TMPLOG" |
		grep -viE 'node_modules|warning|warn|deprecat' |
		head -10 |
		jq -R -s 'split("\n") | map(select(length > 0)) | map({
			type: (capture("^(?:.*:)?(?<line>[0-9]+):?\\s*(?<t>[A-Za-z]*Error)") // {t:"Error"}).t,
			msg: .[0:200],
			file: "",
			line: null
		})' 2>/dev/null) || NODE_ERRORS="[]"
fi

[[ -z "$NODE_ERRORS" ]] && NODE_ERRORS="[]"
ERROR_COUNT=$(echo "$NODE_ERRORS" | jq 'length' 2>/dev/null || echo 0)

# Also extract assertion failures (test-specific)
ASSERTIONS=$(grep -iE 'expect|assert|toBe|toEqual|toHaveBeenCalled|AssertionError' "$TMPLOG" |
	grep -viE 'node_modules|\.d\.ts' |
	head -5 |
	jq -R -s 'split("\n") | map(select(length > 0)) | map(.[0:200])' 2>/dev/null) || ASSERTIONS="[]"

jq -n \
	--argjson errors "$NODE_ERRORS" \
	--argjson count "$ERROR_COUNT" \
	--argjson assertions "$ASSERTIONS" \
	'{errors:$errors, count:$count, assertions:$assertions}'
