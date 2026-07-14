#!/usr/bin/env bash
# 全リソース削除（作成の逆順）。依存関係の順序に注意:
# API → Lambda → IAM(インライン→管理ポリシー→ロール) → DynamoDB
set -uo pipefail

echo "=== API Gateway 削除 ==="
for api_id in $(aws apigatewayv2 get-apis --query "Items[?Name=='order-api-demo'].ApiId" --output text); do
  aws apigatewayv2 delete-api --api-id "${api_id}" && echo "deleted api ${api_id}"
done

echo "=== Lambda 削除 ==="
aws lambda delete-function --function-name order-api && echo "deleted function"

echo "=== IAM ロール削除（ポリシーを外してから）==="
aws iam delete-role-policy --role-name order-api-lambda-role --policy-name orders-table-rw
aws iam detach-role-policy --role-name order-api-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name order-api-lambda-role && echo "deleted role"

echo "=== DynamoDB テーブル削除 ==="
aws dynamodb delete-table --table-name orders --query 'TableDescription.TableStatus'

echo ""
echo "✅ クリーンアップ完了。残存確認:"
aws dynamodb list-tables --output text
aws lambda list-functions --query 'Functions[].FunctionName' --output text
aws apigatewayv2 get-apis --query 'Items[].Name' --output text
