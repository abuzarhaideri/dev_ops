#!/bin/bash

# =============================================================================
# ShopSmart Local Pre-Check Script
# Validates the environment before running Terraform or deployment commands.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Checking local environment...${NC}"
which aws
aws --version

# 1. Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: aws CLI is not installed.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ AWS CLI found.${NC}"

# 2. Check for AWS Credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured or expired.${NC}"
    echo "Run 'aws configure' or export AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN."
    exit 1
fi
echo -e "${GREEN}✅ AWS credentials are valid.${NC}"

# 3. Check for Terraform CLI
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: terraform CLI is not installed.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Terraform CLI found.${NC}"

# 4. Check Terraform formatting
echo -e "${YELLOW}Checking Terraform formatting...${NC}"
if ! terraform -chdir=terraform fmt -check; then
    echo -e "${RED}Error: Terraform files are not formatted. Run 'terraform fmt' in the terraform directory.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Terraform formatting is correct.${NC}"

# 5. Validate Terraform configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
# We need to run init first to validate, but we'll skip it if already initialized
if [ ! -d "terraform/.terraform" ]; then
    echo -e "${YELLOW}Terraform not initialized. Running 'terraform init -backend=false'...${NC}"
    terraform -chdir=terraform init -backend=false
fi

if ! terraform -chdir=terraform validate; then
    echo -e "${RED}Error: Terraform validation failed.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Terraform configuration is valid.${NC}"

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}✅ All local checks passed! You are ready to deploy.${NC}"
echo -e "${GREEN}===========================================${NC}"
