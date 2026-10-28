#!/usr/bin/env bash
# Mostra o status da stack e os eventos mais recentes (somente leitura).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/aws-env.sh"

awsx cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].StackStatus" --output text
awsx cloudformation describe-stack-events --stack-name "$STACK_NAME" --max-items 15 \
  --query "StackEvents[].[Timestamp, LogicalResourceId, ResourceStatus, ResourceStatusReason]" \
  --output text
echo "__RC__$?"
