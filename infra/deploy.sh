#!/usr/bin/env bash
# Cria ou atualiza toda a infraestrutura do lab e publica a Lambda e o site.
#
# Uso (na raiz do projeto):
#   nohup bash infra/deploy.sh > deploy.log 2>&1 &
#
# Etapas:
#   1. Confere a identidade AWS e se o nome da stack está livre (ou é desta stack)
#   2. Cria/atualiza a stack CloudFormation (infra/template.yaml)
#   3. Publica o código de lambda/index.mjs
#   4. Gera site/config.js com a URL da API
#   5. Envia os arquivos do site ao bucket e invalida o cache do CloudFront

set -euo pipefail
trap 'echo "__RC__$?"' EXIT

source "$(dirname "${BASH_SOURCE[0]}")/aws-env.sh"

echo "== Profile: $AWS_PROFILE_LAB | Região: $AWS_REGION_LAB | Stack: $STACK_NAME"
awsx sts get-caller-identity --query "[Account, Arn]" --output text

echo "== Verificando se a stack já existe"
if descricao=$(awsx cloudformation describe-stacks --stack-name "$STACK_NAME" \
      --query "Stacks[0].Description" --output text 2>/dev/null); then
  if [[ "$descricao" != "$STACK_DESCRIPTION_PREFIX"* ]]; then
    echo "Já existe uma stack '$STACK_NAME' que não é deste lab. Abortando." >&2
    exit 1
  fi
  echo "Stack do lab já existe, será atualizada."
else
  echo "Stack não existe, será criada."
fi

echo "== Validando template"
awsx cloudformation validate-template \
  --template-body "file://$RAIZ/infra/template.yaml" > /dev/null

echo "== Criando/atualizando stack (o CloudFront pode levar de 5 a 15 min)"
awsx cloudformation deploy \
  --template-file "$RAIZ/infra/template.yaml" \
  --stack-name "$STACK_NAME" \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset \
  --tags Projeto=mural-recados Origem=escola-da-nuvem-lab

SITE_URL=$(output_stack SiteUrl)
API_URL=$(output_stack ApiUrl)
BUCKET=$(output_stack BucketName)
DISTRIBUICAO=$(output_stack DistributionId)
FUNCAO=$(output_stack FunctionName)

echo "== Publicando código da Lambda ($FUNCAO)"
ZIP="$(mktemp -d)/lambda.zip"
if command -v zip > /dev/null; then
  (cd "$RAIZ/lambda" && zip -q -j "$ZIP" index.mjs)
else
  python3 -c "import sys, zipfile; zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED).write(sys.argv[2], 'index.mjs')" \
    "$ZIP" "$RAIZ/lambda/index.mjs"
fi
awsx lambda update-function-code --function-name "$FUNCAO" \
  --zip-file "fileb://$ZIP" --query "LastUpdateStatus" --output text
awsx lambda wait function-updated --function-name "$FUNCAO"
rm -f "$ZIP"

echo "== Gerando site/config.js"
cat > "$RAIZ/site/config.js" <<EOF
// Gerado por infra/deploy.sh. Invoke URL do stage do API Gateway (sem barra no final).
window.APP_CONFIG = {
  API_URL: "$API_URL"
};
EOF

echo "== Enviando site para s3://$BUCKET"
for arquivo in index.html styles.css app.js config.js; do
  case "$arquivo" in
    *.html) tipo="text/html; charset=utf-8" ;;
    *.css)  tipo="text/css; charset=utf-8" ;;
    *.js)   tipo="application/javascript; charset=utf-8" ;;
  esac
  awsx s3 cp "$RAIZ/site/$arquivo" "s3://$BUCKET/$arquivo" --content-type "$tipo" --only-show-errors
done

echo "== Invalidando cache do CloudFront"
awsx cloudfront create-invalidation --distribution-id "$DISTRIBUICAO" \
  --paths "/*" --query "Invalidation.Id" --output text

echo "== Pronto"
echo "Site: $SITE_URL"
echo "API:  $API_URL/recados"
