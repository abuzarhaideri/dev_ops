#!/bin/bash

# =============================================================================
# ShopSmart Terraform Backend Bootstrap
# Creates the S3 bucket and DynamoDB table for remote state storage.
# =============================================================================

set -e

# Configuration
REGION="us-east-1"
# Get Account ID to make bucket name unique
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="shopsmart-terraform-state-${ACCOUNT_ID}"
TABLE_NAME="terraform-lock"

echo "Creating S3 bucket: ${BUCKET_NAME} in ${REGION}..."
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "Bucket already exists."
else
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}"
    echo "Bucket created."
fi

echo "Enabling versioning on bucket..."
aws s3api put-bucket-versioning --bucket "${BUCKET_NAME}" --versioning-configuration Status=Enabled

echo "Enabling server-side encryption..."
aws s3api put-bucket-encryption --bucket "${BUCKET_NAME}" --server-side-encryption-configuration '{
    "Rules": [
        {
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }
    ]
}'

echo "Creating DynamoDB table: ${TABLE_NAME}..."
if aws dynamodb describe-table --table-name "${TABLE_NAME}" 2>/dev/null; then
    echo "Table already exists."
else
    aws dynamodb create-table \
        --table-name "${TABLE_NAME}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${REGION}"
    echo "Table created."
fi

echo "==========================================="
echo "✅ Bootstrap Complete!"
echo "==========================================="
echo "Please update your terraform/main.tf with this bucket name:"
echo "bucket = \"${BUCKET_NAME}\""
echo "==========================================="
