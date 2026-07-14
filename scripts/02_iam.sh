#!/usr/bin/env bash
# Step 2: Lambda 実行ロール作成（最小権限）
# ポリシーは2枚:
#   1. AWSLambdaBasicExecutionRole (AWS管理) — CloudWatch Logs への書き込み
#   2. インラインポリシー — orders テーブル限定の PutItem / GetItem
set -euo pipefail

REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 信頼ポリシー: 「Lambda サービスがこのロールを被ってよい」という宣言
aws iam create-role \
  --role-name order-api-lambda-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

aws iam attach-role-policy \
  --role-name order-api-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# リソースを orders テーブルの ARN に限定（最小権限）
aws iam put-role-policy \
  --role-name order-api-lambda-role \
  --policy-name orders-table-rw \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Action\": [\"dynamodb:PutItem\", \"dynamodb:GetItem\"],
      \"Resource\": \"arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/orders\"
    }]
  }"

echo "✅ ロール order-api-lambda-role を作成しました"
echo "（IAM の反映には数十秒かかることがあります。Step 3 が AccessDenied になったら少し待って再実行）"
