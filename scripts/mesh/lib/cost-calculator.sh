#!/usr/bin/env bash
# cost-calculator.sh — Per-model cost computation from token_usage table
# Version: 1.0.1
# Usage: source this file, then call calc_cost_from_token_usage <plan_id>
# Pricing (USD per 1M tokens): haiku=0.80/4.00, sonnet=3.00/15.00, opus=15.00/75.00, batch=1.50/7.50

DB_FILE="${PLAN_DB_FILE:-$HOME/.claude/data/dashboard.db}"

# get_model_pricing <model_name>
# Outputs: <input_usd_per_1m> <output_usd_per_1m> <tier>
get_model_pricing() {
	local model
	model=$(echo "$1" | tr '[:upper:]' '[:lower:]')
	if [[ "$model" == *"opus"* ]]; then
		echo "15.00 75.00 opus"
	elif [[ "$model" == *"sonnet"* ]]; then
		echo "3.00 15.00 sonnet"
	elif [[ "$model" == *"haiku"* ]]; then
		echo "0.80 4.00 haiku"
	elif [[ "$model" == *"batch"* ]]; then
		echo "1.50 7.50 batch"
	else
		echo "0.00 0.00 other"
	fi
}

# calc_cost_from_token_usage <plan_id>
# Returns JSON: {"haiku":{tokens,cost},"sonnet":{...},"opus":{...},"batch":{...},"total":X}
calc_cost_from_token_usage() {
	local plan_id="$1"
	[[ "$plan_id" =~ ^[0-9]+$ ]] || {
		echo '{"error":"plan_id must be numeric"}' >&2
		return 1
	}
	[[ -f "$DB_FILE" ]] || {
		echo '{"error":"dashboard DB not found"}' >&2
		return 1
	}

	# Build per-tier aggregates via awk (bash 3.2 compatible — no declare -A)
	local rows
	rows=$(sqlite3 -separator '|' "$DB_FILE" \
		"SELECT model, SUM(input_tokens), SUM(output_tokens) \
		 FROM token_usage WHERE plan_id=$plan_id \
		 GROUP BY model;")

	# Use awk to accumulate per-tier tokens and cost
	echo "$rows" | awk -F'|' '
	BEGIN {
		split("haiku sonnet opus batch other", tiers, " ")
		for (i in tiers) { t = tiers[i]; tok[t]=0; cost[t]=0 }
		price_in["haiku"]=0.80;  price_out["haiku"]=4.00
		price_in["sonnet"]=3.00; price_out["sonnet"]=15.00
		price_in["opus"]=15.00;  price_out["opus"]=75.00
		price_in["batch"]=1.50;  price_out["batch"]=7.50
		price_in["other"]=0.00;  price_out["other"]=0.00
	}
	/^[^|]/ {
		model = $1; in_t = $2+0; out_t = $3+0
		# Classify model into tier
		if      (model ~ /opus/)   tier = "opus"
		else if (model ~ /sonnet/) tier = "sonnet"
		else if (model ~ /haiku/)  tier = "haiku"
		else if (model ~ /batch/)  tier = "batch"
		else                       tier = "other"
		tok[tier]  += in_t + out_t
		cost[tier] += (in_t * price_in[tier] + out_t * price_out[tier]) / 1000000
	}
	END {
		total = cost["haiku"] + cost["sonnet"] + cost["opus"] + cost["batch"]
		printf "{\"haiku\":{\"tokens\":%d,\"cost\":%.6f},", tok["haiku"], cost["haiku"]
		printf "\"sonnet\":{\"tokens\":%d,\"cost\":%.6f},",  tok["sonnet"], cost["sonnet"]
		printf "\"opus\":{\"tokens\":%d,\"cost\":%.6f},",    tok["opus"],   cost["opus"]
		printf "\"batch\":{\"tokens\":%d,\"cost\":%.6f},",   tok["batch"],  cost["batch"]
		printf "\"total\":%.6f}\n", total
	}
	' | jq .
}
