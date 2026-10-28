// Lambda do Mural de Recados.
// Recebe as requisições do API Gateway (Lambda proxy integration) e lê/grava na tabela DynamoDB.
//
// Variáveis de ambiente:
//   TABLE_NAME      nome da tabela DynamoDB (padrão: Recados)
//   ALLOWED_ORIGIN  origem liberada no CORS (padrão: *). Ex.: https://d111111abcdef8.cloudfront.net

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, ScanCommand } from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "node:crypto";

const TABLE_NAME = process.env.TABLE_NAME || "Recados";
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || "*";
const MAX_NOME = 50;
const MAX_MENSAGEM = 280;

// Criado fora do handler para ser reaproveitado entre invocações.
const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));

function resposta(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS"
    },
    body: body === undefined ? "" : JSON.stringify(body)
  };
}

async function listarRecados() {
  const itens = [];
  let ExclusiveStartKey;

  // O Scan devolve no máximo 1 MB por chamada, então seguimos as páginas até o fim.
  do {
    const resultado = await ddb.send(new ScanCommand({ TableName: TABLE_NAME, ExclusiveStartKey }));
    itens.push(...(resultado.Items || []));
    ExclusiveStartKey = resultado.LastEvaluatedKey;
  } while (ExclusiveStartKey);

  itens.sort((a, b) => Number(b.criadoEm) - Number(a.criadoEm));
  return resposta(200, itens);
}

function lerCorpo(event) {
  if (!event.body) return {};
  const texto = event.isBase64Encoded
    ? Buffer.from(event.body, "base64").toString("utf8")
    : event.body;
  return JSON.parse(texto);
}

async function criarRecado(event) {
  let dados;
  try {
    dados = lerCorpo(event);
  } catch {
    return resposta(400, { erro: "O corpo da requisição precisa ser um JSON válido." });
  }

  const nome = typeof dados.nome === "string" ? dados.nome.trim() : "";
  const mensagem = typeof dados.mensagem === "string" ? dados.mensagem.trim() : "";

  if (!nome || !mensagem) {
    return resposta(400, { erro: "Preencha nome e mensagem." });
  }
  if (nome.length > MAX_NOME) {
    return resposta(400, { erro: `O nome pode ter no máximo ${MAX_NOME} caracteres.` });
  }
  if (mensagem.length > MAX_MENSAGEM) {
    return resposta(400, { erro: `A mensagem pode ter no máximo ${MAX_MENSAGEM} caracteres.` });
  }

  const recado = {
    id: randomUUID(),
    nome,
    mensagem,
    criadoEm: Date.now()
  };

  await ddb.send(new PutCommand({ TableName: TABLE_NAME, Item: recado }));
  return resposta(201, { ok: true, id: recado.id });
}

export const handler = async (event) => {
  console.log("Requisição:", event.httpMethod, event.path);

  try {
    switch (event.httpMethod) {
      case "GET":
        return await listarRecados();
      case "POST":
        return await criarRecado(event);
      case "OPTIONS":
        return resposta(204);
      default:
        return resposta(405, { erro: "Método não permitido." });
    }
  } catch (err) {
    // O detalhe vai para o CloudWatch Logs; o navegador recebe só uma mensagem genérica.
    console.error("Erro ao processar requisição:", err);
    return resposta(500, { erro: "Erro interno. Tente novamente." });
  }
};
