#!/usr/bin/env bash
# Remove TODA a infraestrutura do lab: esvazia o bucket do site e apaga a stack.
# Ação irreversível: os recados gravados no DynamoDB serão perdidos.
#
# Uso (na raiz do projeto):
#   nohup bash infra/destroy.sh > destroy.log 2>&1 &

set -euo pipefail
trap 'echo "__RC__$?"' EXIT

source "$(dirname "${BASH_SOURCE[0]}")/aws-env.sh"

echo "== Profile: $AWS_PROFILE_LAB | Região: $AWS_REGION_LAB | Stack: $STACK_NAME"

descricao=$(awsx cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Description" --output text)
if [[ "$descricao" != "$STACK_DESCRIPTION_PREFIX"* ]]; then
  echo "A stack '$STACK_NAME' não é deste lab. Abortando." >&2
  exit 1
fi

BUCKET=$(output_stack BucketName)

echo "== Esvaziando s3://$BUCKET (bucket só contém os arquivos do site)"
for arquivo in index.html styles.css app.js config.js; do
  awsx s3 rm "s3://$BUCKET/$arquivo" --only-show-errors || true
done

echo "== Apagando stack (o CloudFront pode levar de 5 a 15 min)"
awsx cloudformation delete-stack --stack-name "$STACK_NAME"
awsx cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"

echo "== Stack removida"
