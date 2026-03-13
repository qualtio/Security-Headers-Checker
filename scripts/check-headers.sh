#!/usr/bin/env bash
set -euo pipefail

CURL_OPTS=(-s -I --max-time "$TIMEOUT")
[[ "$FOLLOW_REDIRECTS" == "true" ]] && CURL_OPTS+=(-L)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Security Headers Checker"
echo "  URL: $TARGET_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Fetch headers
HEADERS=$(curl "${CURL_OPTS[@]}" "$TARGET_URL" 2>&1) || {
  echo "❌ ERROR: Could not reach $TARGET_URL"
  exit 1
}

HTTP_STATUS=$(echo "$HEADERS" | grep -i "^HTTP/" | tail -1 | awk '{print $2}')
echo "HTTP Status: $HTTP_STATUS"
echo ""

# All security headers to check and their recommended values
declare -A RECOMMENDED=(
  ["Strict-Transport-Security"]="max-age=31536000"
  ["X-Content-Type-Options"]="nosniff"
  ["X-Frame-Options"]="DENY or SAMEORIGIN"
  ["Content-Security-Policy"]="default-src 'self'"
  ["Permissions-Policy"]="define allowed browser features"
  ["Referrer-Policy"]="strict-origin-when-cross-origin"
  ["X-XSS-Protection"]="0 (deprecated, set to 0)"
  ["Cross-Origin-Opener-Policy"]="same-origin"
  ["Cross-Origin-Resource-Policy"]="same-origin"
  ["Cache-Control"]="no-store or no-cache for sensitive pages"
)

MISSING_REQUIRED=()
MISSING_WARN=()
PRESENT=()
TOTAL_CHECKS=${#RECOMMENDED[@]}
PASSED_CHECKS=0

check_header() {
  local header="$1"
  local value
  value=$(echo "$HEADERS" | grep -i "^${header}:" | head -1 | cut -d':' -f2- | xargs || echo "")
  echo "$value"
}

echo "┌─────────────────────────────────────────────┐"
echo "│              Header Analysis                 │"
echo "└─────────────────────────────────────────────┘"

for header in "${!RECOMMENDED[@]}"; do
  value=$(check_header "$header")
  if [[ -n "$value" ]]; then
    echo "✅  ${header}: ${value}"
    PRESENT+=("$header")
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
  else
    # Check if required
    if echo "$FAIL_ON_MISSING" | grep -qi "$header"; then
      echo "❌  ${header}: MISSING (required) — recommended: ${RECOMMENDED[$header]}"
      MISSING_REQUIRED+=("$header")
    elif echo "$WARN_ON_MISSING" | grep -qi "$header"; then
      echo "⚠️   ${header}: MISSING (warning) — recommended: ${RECOMMENDED[$header]}"
      MISSING_WARN+=("$header")
    else
      echo "ℹ️   ${header}: not present"
    fi
  fi
done

echo ""
SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Security Score: ${SCORE}/100"
echo "  Present: ${#PRESENT[@]}/${TOTAL_CHECKS} headers"
echo "  Missing (required): ${#MISSING_REQUIRED[@]}"
echo "  Missing (warnings): ${#MISSING_WARN[@]}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Set outputs
MISSING_REQ_STR=$(IFS=','; echo "${MISSING_REQUIRED[*]}")
echo "score=${SCORE}" >> "$GITHUB_OUTPUT"
echo "missing_required=${MISSING_REQ_STR}" >> "$GITHUB_OUTPUT"

# Write JSON report if requested
if [[ -n "${REPORT_FILE:-}" ]]; then
  PRESENT_JSON=$(printf '"%s"
' "${PRESENT[@]}" | jq -s .)
  MISSING_REQ_JSON=$(printf '"%s"
' "${MISSING_REQUIRED[@]:-}" | jq -s .)
  MISSING_WARN_JSON=$(printf '"%s"
' "${MISSING_WARN[@]:-}" | jq -s .)
  jq -n \
    --arg url "$TARGET_URL" \
    --arg status "$HTTP_STATUS" \
    --argjson score "$SCORE" \
    --argjson present "$PRESENT_JSON" \
    --argjson missing_required "$MISSING_REQ_JSON" \
    --argjson missing_warn "$MISSING_WARN_JSON" \
    '{url: $url, http_status: $status, score: $score, present: $present, missing_required: $missing_required, missing_warnings: $missing_warn}' \
    > "$REPORT_FILE"
  echo "report_path=${REPORT_FILE}" >> "$GITHUB_OUTPUT"
  echo "📄 Report written to: ${REPORT_FILE}"
fi

if [[ ${#MISSING_REQUIRED[@]} -eq 0 ]]; then
  echo "passed=true" >> "$GITHUB_OUTPUT"
  echo "🎉 All required security headers are present!"
else
  echo "passed=false" >> "$GITHUB_OUTPUT"
  echo ""
  echo "❌ Missing required headers: ${MISSING_REQ_STR}"
  echo "📖 Reference: https://owasp.org/www-project-secure-headers/"
  exit 1
fi
