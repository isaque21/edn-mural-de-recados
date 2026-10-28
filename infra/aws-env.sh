#!/usr/bin/env bash
# Lê .aws-profile e .aws-region da raiz do projeto (removendo BOM UTF-8) e define
# as variáveis usadas pelos outros scripts.

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_NAME="${STACK_NAME:-mural-recados}"
STACK_DESCRIPTION_PREFIX="Lab Escola da Nuvem - Mural de Recados"

ler_config() {
  local arquivo="$RAIZ/$1"
  if [[ ! -f "$arquivo" ]]; then
    echo "Arquivo $1 não encontrado na raiz do projeto." >&2
    exit 1
  fi
  sed "1s/^\xEF\xBB\xBF//" "$arquivo" | head -1 | tr -d "[:space:]"
}

AWS_PROFILE_LAB="$(ler_config .aws-profile)"
AWS_REGION_LAB="$(ler_config .aws-region)"

awsx() {
  aws "$@" --profile "$AWS_PROFILE_LAB" --region "$AWS_REGION_LAB"
}

output_stack() {
  awsx cloudformation describe-stacks --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}
