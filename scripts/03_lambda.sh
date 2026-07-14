#!/usr/bin/env bash
# Step 3: Lambda 関数作成
# コードを zip に固めてアップロードし、環境変数でテーブル名を渡す。
# boto3 は Lambda ランタイムに同梱されているため zip に含める必要はない。
set -euo pipefail
cd "$(dirname "$0")/.."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

(cd src && zip -q ../function.zip handler.py)

aws lambda create-function \
  --function-name order-api \
  --runtime python3.12 \
  --architectures arm64 \
  --handler handler.lambda_handler \
  --zip-file fileb://function.zip \
  --role "arn:aws:iam::${ACCOUNT_ID}:role/order-api-lambda-role" \
  --environment "Variables={ORDERS_TABLE=orders}" \
  --timeout 10

echo "✅ Lambda 関数 order-api を作成しました。直接 invoke してテストします..."
aws lambda wait function-active --function-name order-api

# API Gateway を通す前に、Lambda 単体をイベント JSON で直接テスト（切り分けの基本）
aws lambda invoke \
  --function-name order-api \
  --payload '{"routeKey": "POST /orders", "body": "{\"customer\": \"テスト太郎\", \"items\": [{\"name\": \"ギフトセット\", \"price\": 5400, \"qty\": 2}]}"}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/lambda_out.json

cat /tmp/lambda_out.json
echo ""
echo "✅ statusCode 201 が返っていれば Lambda 単体は正常です"
