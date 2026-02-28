#!/bin/bash
set -euo pipefail
# Quality Collector - Engineering Fundamentals Checklist
# Usage: ./collect-quality.sh [project_path]
# Output: JSON to stdout

# Version: 1.1.0
set -euo pipefail

PROJECT_PATH="${1:-.}"
cd "$PROJECT_PATH"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialize checks
HAS_TESTS=false
HAS_COVERAGE=false
COVERAGE_VALUE=0
HAS_README=false
HAS_API_DOCS=false
HAS_ESLINT=false
HAS_PRETTIER=false
HAS_TYPESCRIPT=false
HAS_GITIGNORE=false
HAS_EDITORCONFIG=false
HAS_CI=false
HAS_DOCKER=false
HAS_ENV_EXAMPLE=false
NO_SECRETS=true

# Check for tests
if [[ -d "tests" ]] || [[ -d "__tests__" ]] || [[ -d "test" ]] || [[ -d "spec" ]]; then
	HAS_TESTS=true
fi
if [[ -f "package.json" ]] && grep -q '"test"' package.json 2>/dev/null; then
	HAS_TESTS=true
fi
if [[ -f "pytest.ini" ]] || [[ -f "setup.py" ]] || [[ -d "tests" ]]; then
	HAS_TESTS=true
fi

# Check for coverage
if [[ -d "coverage" ]] || [[ -f "coverage.json" ]] || [[ -f ".nyc_output" ]]; then
	HAS_COVERAGE=true
	# Try to extract coverage percentage
	if [[ -f "coverage/coverage-summary.json" ]]; then
		COVERAGE_VALUE=$(jq '.total.lines.pct // 0' coverage/coverage-summary.json 2>/dev/null || echo "0")
	fi
fi

# Check documentation
[[ -f "README.md" ]] || [[ -f "readme.md" ]] && HAS_README=true
[[ -d "docs" ]] || [[ -f "openapi.yaml" ]] || [[ -f "swagger.json" ]] && HAS_API_DOCS=true

# Check linting/formatting
[[ -f ".eslintrc" ]] || [[ -f ".eslintrc.js" ]] || [[ -f ".eslintrc.json" ]] || [[ -f "eslint.config.js" ]] && HAS_ESLINT=true
[[ -f ".prettierrc" ]] || [[ -f ".prettierrc.js" ]] || [[ -f ".prettierrc.json" ]] && HAS_PRETTIER=true
[[ -f "tsconfig.json" ]] && HAS_TYPESCRIPT=true

# Check project config
[[ -f ".gitignore" ]] && HAS_GITIGNORE=true
[[ -f ".editorconfig" ]] && HAS_EDITORCONFIG=true
[[ -f ".env.example" ]] || [[ -f ".env.sample" ]] && HAS_ENV_EXAMPLE=true

# Check CI/CD
[[ -d ".github/workflows" ]] || [[ -f ".gitlab-ci.yml" ]] || [[ -f "azure-pipelines.yml" ]] || [[ -f "Jenkinsfile" ]] && HAS_CI=true

# Check Docker
[[ -f "Dockerfile" ]] || [[ -f "docker-compose.yml" ]] && HAS_DOCKER=true

# Check for secrets in config files (anchored regex, restricted scope)
if grep -rqE "^[A-Z_]*(PASSWORD|SECRET|API_KEY)\s*=\s*['\"][^'\"]+['\"]" \
	--include="*.env*" --include="*.yaml" --include="*.yml" --include="*.json" \
	--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.next \
	. 2>/dev/null; then
	NO_SECRETS=false
fi

# Check for .env files committed (should be in .gitignore)
if [[ -f ".env" ]] && ! grep -q "^\.env$" .gitignore 2>/dev/null; then
	NO_SECRETS=false
fi

# Calculate score
SCORE=0
MAX_SCORE=100
CHECKS_PASSED=0
TOTAL_CHECKS=12

$HAS_TESTS && ((CHECKS_PASSED++))
$HAS_COVERAGE && ((CHECKS_PASSED++))
$HAS_README && ((CHECKS_PASSED++))
$HAS_API_DOCS && ((CHECKS_PASSED++))
$HAS_ESLINT && ((CHECKS_PASSED++))
$HAS_PRETTIER && ((CHECKS_PASSED++))
$HAS_TYPESCRIPT && ((CHECKS_PASSED++))
$HAS_GITIGNORE && ((CHECKS_PASSED++))
$HAS_CI && ((CHECKS_PASSED++))
$HAS_DOCKER && ((CHECKS_PASSED++))
$HAS_ENV_EXAMPLE && ((CHECKS_PASSED++))
$NO_SECRETS && ((CHECKS_PASSED++))

SCORE=$((CHECKS_PASSED * 100 / TOTAL_CHECKS))

# Build output
jq -n \
	--arg collector "quality" \
	--arg timestamp "$TIMESTAMP" \
	--argjson score "$SCORE" \
	--argjson hasTests "$HAS_TESTS" \
	--argjson hasCoverage "$HAS_COVERAGE" \
	--argjson coverage "$COVERAGE_VALUE" \
	--argjson hasReadme "$HAS_README" \
	--argjson hasApiDocs "$HAS_API_DOCS" \
	--argjson hasEslint "$HAS_ESLINT" \
	--argjson hasPrettier "$HAS_PRETTIER" \
	--argjson hasTypescript "$HAS_TYPESCRIPT" \
	--argjson hasGitignore "$HAS_GITIGNORE" \
	--argjson hasCI "$HAS_CI" \
	--argjson hasDocker "$HAS_DOCKER" \
	--argjson hasEnvExample "$HAS_ENV_EXAMPLE" \
	--argjson noSecrets "$NO_SECRETS" \
	--argjson checksPassed "$CHECKS_PASSED" \
	--argjson totalChecks "$TOTAL_CHECKS" \
	'{
        collector: $collector,
        timestamp: $timestamp,
        status: "success",
        data: {
            score: $score,
            checksPassed: $checksPassed,
            totalChecks: $totalChecks,
            fundamentals: {
                tests: { exists: $hasTests, coverage: (if $hasCoverage then $coverage else null end) },
                documentation: { readme: $hasReadme, apiDocs: $hasApiDocs },
                codeQuality: { eslint: $hasEslint, prettier: $hasPrettier, typescript: $hasTypescript },
                projectConfig: { gitignore: $hasGitignore, envExample: $hasEnvExample, editorconfig: false },
                devops: { ci: $hasCI, docker: $hasDocker },
                security: { noSecrets: $noSecrets }
            },
            lastCheck: $timestamp
        }
    }'
