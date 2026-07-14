"""注文API Lambda ハンドラ。

API Gateway (HTTP API) からのリクエストを受け、DynamoDB の orders テーブルを
読み書きする。ルーティングは routeKey で分岐する。

- POST /orders            : 注文を登録する
- GET  /orders/{order_id} : 注文を1件取得する
"""

import json
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import boto3

TABLE_NAME = os.environ["ORDERS_TABLE"]

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def _response(status: int, body: dict) -> dict:
    """API Gateway (payload v2.0) が期待する形のレスポンスを組み立てる。"""
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, ensure_ascii=False, default=str),
    }


def _create_order(event: dict) -> dict:
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "リクエストボディが JSON ではありません"})

    customer = payload.get("customer")
    items = payload.get("items")
    if not customer or not isinstance(items, list) or not items:
        return _response(400, {"error": "customer と items（1件以上の配列）は必須です"})

    for item in items:
        if not item.get("name") or "price" not in item or "qty" not in item:
            return _response(400, {"error": "items の各要素は name / price / qty が必須です"})

    # DynamoDB は float を受け付けないため金額は Decimal で扱う
    total = sum(Decimal(str(i["price"])) * int(i["qty"]) for i in items)
    order = {
        "order_id": str(uuid.uuid4()),
        "customer": customer,
        "items": [
            {"name": i["name"], "price": Decimal(str(i["price"])), "qty": int(i["qty"])}
            for i in items
        ],
        "total": total,
        "status": "accepted",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    table.put_item(Item=order)
    return _response(201, order)


def _get_order(event: dict) -> dict:
    order_id = event["pathParameters"]["order_id"]
    result = table.get_item(Key={"order_id": order_id})
    if "Item" not in result:
        return _response(404, {"error": f"注文 {order_id} は存在しません"})
    return _response(200, result["Item"])


def lambda_handler(event: dict, context) -> dict:
    route = event.get("routeKey", "")
    if route == "POST /orders":
        return _create_order(event)
    if route == "GET /orders/{order_id}":
        return _get_order(event)
    return _response(404, {"error": f"未定義のルートです: {route}"})
