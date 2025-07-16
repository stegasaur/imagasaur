#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export LOCALSTACK_HOST=localhost
export EDGE_PORT=4566

awslocal() {
  aws --endpoint-url=http://$LOCALSTACK_HOST:$EDGE_PORT "$@"
}

# Create S3 buckets
awslocal s3 mb s3://imagasaur-uploads
awslocal s3 mb s3://imagasaur-processed
