#!/usr/bin/env bash
# Step 4: API Gateway (HTTP API) 作成
# 構成: API本体 → 統合(Lambdaプロキシ) → ルート2本 → ステージ($default 自動デプロイ)
# 最後に「API Gateway が Lambda を呼んでよい」というリソースベース許可を Lambda 側に付与。
set -euo pipefail

REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:order-api"

API_ID=$(aws apigatewayv2 create-api \
  --name order-api-demo \
  --protocol-type HTTP \
  --query ApiId --output text)
echo "API_ID: ${API_ID}"

# 統合 = 「このAPIへのリクエストを Lambda にプロキシで渡す」設定 (payload v2.0)
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id "${API_ID}" \
  --integration-type AWS_PROXY \
  --integration-uri "${LAMBDA_ARN}" \
  --payload-format-version 2.0 \
  --query IntegrationId --output text)

aws apigatewayv2 create-route --api-id "${API_ID}" \
  --route-key "POST /orders" --target "integrations/${INTEGRATION_ID}"
aws apigatewayv2 create-route --api-id "${API_ID}" \
  --route-key "GET /orders/{order_id}" --target "integrations/${INTEGRATION_ID}"

aws apigatewayv2 create-stage --api-id "${API_ID}" \
  --stage-name '$default' --auto-deploy

# Lambda 側のリソースベースポリシー: この API からの invoke を許可
aws lambda add-permission \
  --function-name order-api \
  --statement-id apigw-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*"

ENDPOINT="https://${API_ID}.execute-api.${REGION}.amazonaws.com"
echo ""
echo "✅ 完成。エンドポイント: ${ENDPOINT}"
echo "${ENDPOINT}" > /tmp/order_api_endpoint.txt
