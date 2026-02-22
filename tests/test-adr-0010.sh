
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Test: Status Accepted in ADR 0010

## Should contain 'Status: Accepted'

grep 'Status.*Accepted' docs/adr/0010-multi-provider-orchestration.md || (echo 'FAIL: Status Accepted not found' && exit 1)

# Test: delegate.sh mention in ADR 0010

## Should mention 'delegate.sh'

grep 'delegate.sh' docs/adr/0010-multi-provider-orchestration.md || (echo 'FAIL: delegate.sh not found' && exit 1)
