#!/usr/bin/env bash
# Step 1: DynamoDB テーブル作成
# キー設計: 「注文IDで1件引く」というアクセスパターンだけなので PK = order_id のみ。
# 課金モード: PAY_PER_REQUEST（オンデマンド）。デモ用途では実質0円。
set -euo pipefail

aws dynamodb create-table \
  --table-name orders \
  --attribute-definitions AttributeName=order_id,AttributeType=S \
  --key-schema AttributeName=order_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

echo "テーブル作成をリクエストしました。ACTIVE になるまで待ちます..."
aws dynamodb wait table-exists --table-name orders
echo "✅ orders テーブルが ACTIVE になりました"
aws dynamodb describe-table --table-name orders --query 'Table.{Name:TableName,Status:TableStatus,Keys:KeySchema}'
