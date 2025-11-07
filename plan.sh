#!/bin/bash
set -e


AWS_REGION="eu-west-2"
ENVIRONMENT="test"
S3_BUCKET="terraform-statefile-backends3"


echo "Initializing Terraform with backend config for environment: ${ENVIRONMENT}"
terraform init -reconfigure \
  -backend-config="bucket=${S3_BUCKET}" \
  -backend-config="key=envs/${ENVIRONMENT}/Troubleshoot .tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="encrypt=true" \
  


echo "Validating Terraform configuration..."
terraform validate

echo "Planning Terraform changes..."
terraform plan -out=terraformplan -input=false