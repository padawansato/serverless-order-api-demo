#!/usr/bin/env bash
# Step 5: エンドツーエンド動作確認（curl → API Gateway → Lambda → DynamoDB）
set -euo pipefail

ENDPOINT=$(cat /tmp/order_api_endpoint.txt)

echo "=== 注文を登録 (POST /orders) ==="
CREATED=$(curl -s -X POST "${ENDPOINT}/orders" \
  -H "Content-Type: application/json" \
  -d '{"customer": "佐藤太郎", "items": [{"name": "お中元ギフトA", "price": 5400, "qty": 2}, {"name": "送料", "price": 550, "qty": 1}]}')
echo "${CREATED}" | python3 -m json.tool

ORDER_ID=$(echo "${CREATED}" | python3 -c "import sys, json; print(json.load(sys.stdin)['order_id'])")

echo ""
echo "=== 登録した注文を取得 (GET /orders/${ORDER_ID}) ==="
curl -s "${ENDPOINT}/orders/${ORDER_ID}" | python3 -m json.tool

echo ""
echo "=== 存在しない注文 (404 の確認) ==="
curl -s "${ENDPOINT}/orders/does-not-exist" | python3 -m json.tool

echo ""
echo "=== バリデーションエラー (400 の確認) ==="
curl -s -X POST "${ENDPOINT}/orders" -H "Content-Type: application/json" -d '{"customer": ""}' | python3 -m json.tool

echo ""
echo "=== DynamoDB に実データが入っていることを CLI からも確認 ==="
aws dynamodb get-item --table-name orders --key "{\"order_id\": {\"S\": \"${ORDER_ID}\"}}" --query 'Item.{order_id:order_id.S,customer:customer.S,total:total.N,status:status.S}"' 2>/dev/null \
  || aws dynamodb get-item --table-name orders --key "{\"order_id\": {\"S\": \"${ORDER_ID}\"}}"
