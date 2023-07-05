source .env
echo "Invoking $AUTOTASK_WEBHOOK_URL..."
curl -s -XPOST "$AUTOTASK_WEBHOOK_URL" -d "@./tmp/request.json" -H "Content-Type: application/json" | jq -r 'if .status == "success" then (.result | fromjson | .txHash) else {result,message,status} end'