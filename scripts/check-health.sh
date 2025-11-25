#!/bin/bash
###############################################################################
# Check Health of Instance
###############################################################################

ENDPOINT=${1:-http://localhost:8080/api/health}
TIMEOUT=5

echo "Checking health at: $ENDPOINT"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" --max-time $TIMEOUT "$ENDPOINT")
HTTP_CODE=$(echo "$RESPONSE" | grep HTTP_CODE | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE/d')

echo "Response:"
echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
echo ""
echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ HEALTHY"
    exit 0
else
    echo "❌ UNHEALTHY"
    exit 1
fi
