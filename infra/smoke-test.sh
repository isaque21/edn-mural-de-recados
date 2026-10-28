#!/usr/bin/env bash
# Verificações rápidas do ambiente publicado. Não grava nada no DynamoDB:
# o único POST enviado é inválido e a Lambda o rejeita com 400.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/aws-env.sh"

SITE_URL=$(output_stack SiteUrl)
API_URL=$(output_stack ApiUrl)
BUCKET=$(output_stack BucketName)
echo "Site: $SITE_URL | API: $API_URL | Bucket: $BUCKET"

falhas=0
checar() { # descricao esperado obtido
  if [[ "$3" == "$2" ]]; then echo "OK    $1 ($3)"; else echo "FALHA $1 (esperado $2, obtido $3)"; falhas=$((falhas+1)); fi
}
status() { curl -s -o /dev/null -w "%{http_code}" "$@"; }
header() { curl -s -D - -o /dev/null "${@:2}" | tr -d '\r' | grep -i "^$1:" | cut -d' ' -f2- ; }

checar "CloudFront serve index.html"            200 "$(status "$SITE_URL/")"
checar "config.js aponta para a API"            1   "$(curl -s "$SITE_URL/config.js" | grep -c "$API_URL")"
checar "Acesso direto ao S3 bloqueado"          403 "$(status "https://$BUCKET.s3.amazonaws.com/index.html")"
checar "GET /recados"                           200 "$(status -H "Origin: $SITE_URL" "$API_URL/recados")"
checar "GET devolve CORS do CloudFront"         "$SITE_URL" "$(header access-control-allow-origin -H "Origin: $SITE_URL" "$API_URL/recados")"
checar "Preflight OPTIONS"                      200 "$(status -X OPTIONS -H "Origin: $SITE_URL" -H "Access-Control-Request-Method: POST" "$API_URL/recados")"
checar "POST inválido rejeitado pela Lambda"    400 "$(status -X POST -H "Content-Type: application/json" -d '{"nome":"","mensagem":""}' "$API_URL/recados")"
echo "Corpo do GET: $(curl -s "$API_URL/recados")"

echo "Falhas: $falhas"
echo "__RC__$falhas"
