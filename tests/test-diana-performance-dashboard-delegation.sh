#!/bin/bash
# Diana Performance Dashboard Delegation Intelligence Test

grep -i 'delegation' agents/core_utility/diana-performance-dashboard.md || exit 1
grep -E 'KPI|model_effectiveness' agents/core_utility/diana-performance-dashboard.md || exit 1
