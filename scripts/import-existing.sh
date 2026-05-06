#!/bin/bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

echo "Importing existing resources into Terraform state..."

# Helper to import if not already in state
import_resource() {
  terraform -chdir=terraform import -var="aws_region=$REGION" -var="lab_role_arn=arn:aws:iam::$ACCOUNT_ID:role/LabRole" $1 $2 || echo "$1 already imported or not found."
}

import_resource aws_s3_bucket.artifacts shopsmart-artifacts-${ACCOUNT_ID}
import_resource aws_ecr_repository.app shopsmart-backend
import_resource aws_cloudwatch_log_group.app /ecs/shopsmart-backend
import_resource aws_ecs_cluster.main shopsmart-cluster
import_resource aws_ecs_service.app shopsmart-cluster/shopsmart-service
import_resource aws_dynamodb_table.terraform_lock terraform-lock

# Security Group needs ID lookup
SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=shopsmart-ecs-sg --query "SecurityGroups[0].GroupId" --output text)
if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
  import_resource aws_security_group.ecs $SG_ID
fi

echo "Import complete! Now try running your deployment again."
