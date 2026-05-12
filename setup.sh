#!/usr/bin/env bash
set -euo pipefail

# Konfiguracja
ENDPOINT="http://localhost:4566"
PROFILE="local"            # opcjonalnie: aws --profile $PROFILE ...
REGION="us-east-1"
BUCKET="waf-file-uploads-demo"
LAMBDA_NAME="waf-upload-lambda"
API_NAME="waf-upload-api"
STAGE_NAME="dev"
WEBACL_NAME="waf-demo-acl"

AWS="aws --endpoint-url $ENDPOINT"

echo "1) Tworzę bucket S3: $BUCKET"
$AWS s3api create-bucket --bucket "$BUCKET" --region "$REGION" || true

echo "2) Przygotowuję kod Lambda (python)"
TMPDIR=$(mktemp -d)
cat > "$TMPDIR/lambda_function.py" <<'PY'
import os
import json
import base64
import boto3
from datetime import datetime

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # API Gateway v2 proxy: body może być base64-encoded
    is_base64 = event.get("isBase64Encoded", False)
    body = event.get("body", "")
    headers = event.get("headers", {}) or {}
    content_type = headers.get("content-type") or headers.get("Content-Type") or "application/octet-stream"

    # nazwa pliku z nagłówka lub timestamp
    filename = headers.get("x-filename") or f"upload-{datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')}"
    if is_base64:
        data = base64.b64decode(body)
    else:
        data = body.encode('utf-8')

    bucket = os.environ.get("TARGET_BUCKET")
    if not bucket:
        return {"statusCode":500, "body":"TARGET_BUCKET not set"}

    # zapis do S3
    s3.put_object(Bucket=bucket, Key=filename, Body=data, ContentType=content_type)

    return {
        "statusCode": 200,
        "body": json.dumps({"message":"uploaded","key":filename})
    }
PY

pushd "$TMPDIR" >/dev/null
zip -r lambda.zip lambda_function.py >/dev/null
popd >/dev/null

echo "3) Tworzę funkcję Lambda"
# role może być fikcyjne w MiniStack
ROLE_ARN="arn:aws:iam::000000000000:role/lambda-role"
$AWS lambda create-function \
  --function-name "$LAMBDA_NAME" \
  --runtime python3.9 \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://"$TMPDIR/lambda.zip" \
  --role "$ROLE_ARN" \
  --environment "Variables={TARGET_BUCKET=$BUCKET}" \
  --region "$REGION"

# pobierz ARN funkcji
LAMBDA_ARN=$($AWS lambda get-function --function-name "$LAMBDA_NAME" --query 'Configuration.FunctionArn' --output text)
echo "Lambda ARN: $LAMBDA_ARN"

echo "4) Tworzę API Gateway (HTTP API v2)"
API_ID=$($AWS apigatewayv2 create-api --name "$API_NAME" --protocol-type HTTP --query 'ApiId' --output text)
echo "API ID: $API_ID"

echo "5) Dodaję uprawnienie dla API Gateway do wywoływania Lambdy"
# source-arn pattern dla apigatewayv2: arn:aws:execute-api:region:account:apiId/*
SOURCE_ARN="arn:aws:execute-api:$REGION:000000000000:$API_ID/*/*/*"
$AWS lambda add-permission \
  --function-name "$LAMBDA_NAME" \
  --statement-id "AllowAPIGatewayInvoke" \
  --action "lambda:InvokeFunction" \
  --principal apigateway.amazonaws.com \
  --source-arn "$SOURCE_ARN" || true

echo "6) Tworzę integrację Lambda (AWS_PROXY)"
# integration-uri format:
INTEGRATION_URI="arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"
INTEGRATION_ID=$($AWS apigatewayv2 create-integration \
  --api-id "$API_ID" \
  --integration-type AWS_PROXY \
  --integration-uri "$INTEGRATION_URI" \
  --payload-format-version "2.0" \
  --query 'IntegrationId' --output text)
echo "Integration ID: $INTEGRATION_ID"

echo "7) Tworzę route ANY /upload"
$AWS apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "POST /upload" \
  --target "integrations/$INTEGRATION_ID"

echo "8) Tworzę stage $STAGE_NAME"
$AWS apigatewayv2 create-stage \
  --api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --auto-deploy

# resource ARN do associate-web-acl (format MiniStack)
API_STAGE_ARN="arn:aws:apigateway:$REGION:000000000000:/apis/$API_ID/stages/$STAGE_NAME"
echo "API stage ARN: $API_STAGE_ARN"

echo "9) Tworzę WebACL (WAFv2) w trybie COUNT (domyślnie Allow)"
WEBACL_JSON=$($AWS wafv2 create-web-acl \
  --name "$WEBACL_NAME" \
  --scope REGIONAL \
  --default-action Allow={} \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName="$WEBACL_NAME" \
  --rules '[]' \
  --query 'Summary' --output json)
WEBACL_ARN=$($AWS wafv2 list-web-acls --scope REGIONAL --query "WebACLs[?Name=='$WEBACL_NAME'].ARN | [0]" --output text)
echo "WebACL ARN: $WEBACL_ARN"

echo "10) Associate WebACL -> API stage"
$AWS wafv2 associate-web-acl \
  --web-acl-arn "$WEBACL_ARN" \
  --resource-arn "$API_STAGE_ARN"

echo "Setup zakończony."
echo
echo "Endpoint do testów (MiniStack execute-api):"
echo "http://localhost/_aws/execute-api/$API_ID/$STAGE_NAME/upload"
echo
echo "Przykład wysyłki pliku (curl):"
echo "curl -X POST \"http://localhost/_aws/execute-api/$API_ID/$STAGE_NAME/upload\" -H \"x-filename: test.pdf\" --data-binary @./test.pdf -H \"Content-Type: application/pdf\""
echo
echo "Jeśli chcesz zmienić WebACL na BLOCK, zaktualizuj default-action lub dodaj reguły i użyj update-web-acl." 
