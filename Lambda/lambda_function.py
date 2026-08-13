import json
import os
from decimal import Decimal
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError


dynamodb = boto3.resource("dynamodb")

TABLE_NAME = os.environ["DYNAMODB_TABLE_NAME"]

table = dynamodb.Table(TABLE_NAME)


REQUIRED_FIELDS = [
    "claimId",
    "customerId",
    "policyId",
    "claimType",
    "amount"
]

VALID_CLAIM_TYPES = {
    "AUTO",
    "HOME",
    "HEALTH",
    "LIFE",
    "TRAVEL"
}


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(body)
    }


def lambda_handler(event, context):

    print("Received event:")
    print(json.dumps(event))

    # -----------------------------------------------------
    # 1. Read request body
    # -----------------------------------------------------

    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return response(
            400,
            {
                "error": "Request body must contain valid JSON"
            }
        )

    # -----------------------------------------------------
    # 2. Validate required fields
    # -----------------------------------------------------

    for field in REQUIRED_FIELDS:

        if field not in body:
            return response(
                400,
                {
                    "error": f"Missing required field: {field}"
                }
            )

    # -----------------------------------------------------
    # 3. Validate string fields
    # -----------------------------------------------------

    string_fields = [
        "claimId",
        "customerId",
        "policyId",
        "claimType"
    ]

    for field in string_fields:

        if not isinstance(body[field], str):
            return response(
                400,
                {
                    "error": f"{field} must be a string"
                }
            )

        if not body[field].strip():
            return response(
                400,
                {
                    "error": f"{field} cannot be empty"
                }
            )

    # -----------------------------------------------------
    # 4. Validate claim type
    # -----------------------------------------------------

    claim_type = body["claimType"].upper()

    if claim_type not in VALID_CLAIM_TYPES:
        return response(
            400,
            {
                "error": (
                    f"Invalid claimType. "
                    f"Allowed values: {sorted(VALID_CLAIM_TYPES)}"
                )
            }
        )

    # -----------------------------------------------------
    # 5. Validate amount
    # -----------------------------------------------------

    amount = body["amount"]

    if isinstance(amount, bool):
        return response(
            400,
            {
                "error": "amount must be a number"
            }
        )

    if not isinstance(amount, (int, float)):
        return response(
            400,
            {
                "error": "amount must be a number"
            }
        )

    if amount <= 0:
        return response(
            400,
            {
                "error": "amount must be greater than zero"
            }
        )

    # DynamoDB does not accept Python float directly.
    amount = Decimal(str(amount))

    # -----------------------------------------------------
    # 6. Prepare DynamoDB item
    # -----------------------------------------------------

    claim_id = body["claimId"].strip()

    item = {
        "claimId": claim_id,
        "customerId": body["customerId"].strip(),
        "policyId": body["policyId"].strip(),
        "claimType": claim_type,
        "amount": amount,
        "description": body.get("description", ""),
        "status": "SUBMITTED",
        "createdAt": datetime.now(timezone.utc).isoformat()
    }

    # -----------------------------------------------------
    # 7. Insert only if claimId does not already exist
    # -----------------------------------------------------

    try:

        table.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(claimId)"
        )

    except ClientError as error:

        error_code = error.response["Error"]["Code"]

        if error_code == "ConditionalCheckFailedException":

            print(f"Duplicate claim detected: {claim_id}")

            return response(
                409,
                {
                    "error": f"Claim ID {claim_id} already exists"
                }
            )

        print("DynamoDB error:")
        print(error)

        return response(
            500,
            {
                "error": "Unable to save claim"
            }
        )

    # -----------------------------------------------------
    # 8. Success
    # -----------------------------------------------------

    print(f"Claim {claim_id} created successfully")

    return response(
        201,
        {
            "message": "Claim created successfully",
            "claimId": claim_id,
            "status": "SUBMITTED"
        }
    )