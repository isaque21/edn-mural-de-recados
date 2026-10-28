(function () {
  "use strict";

  var config = window.APP_CONFIG || {};
  var API_URL = String(config.API_URL || "").replace(/\/+$/, "");

  var form = document.getElementById("form-recado");
  var inputNome = document.getElementById("nome");
  var inputMensagem = document.getElementById("mensagem");
  var btnEnviar = document.getElementById("btn-enviar");
  var btnAtualizar = document.getElementById("btn-atualizar");
  var lista = document.getElementById("lista-recados");
  var status = document.getElementById("status");

  function apiConfigurada() {
    return API_URL.indexOf("https://") === 0;
  }

  function setStatus(texto, tipo) {
    status.textContent = texto;
    status.className = tipo || "";
  }

  function mostrarMensagemLista(texto) {
    lista.replaceChildren();
    var li = document.createElement("li");
    li.className = "vazio";
    li.textContent = texto;
    lista.appendChild(li);
  }

  function formatarData(epochMs) {
    var n = Number(epochMs);
    if (!n) return "";
    return new Date(n).toLocaleString("pt-BR");
  }

  // Usa textContent para nunca interpretar o conteúdo do usuário como HTML (evita XSS).
  function renderizar(recados) {
    if (!Array.isArray(recados) || recados.length === 0) {
      mostrarMensagemLista("Nenhum recado ainda. Seja o primeiro!");
      return;
    }

    recados.sort(function (a, b) {
      return Number(b.criadoEm) - Number(a.criadoEm);
    });

    lista.replaceChildren();
    recados.forEach(function (r) {
      var li = document.createElement("li");

      var cabecalho = document.createElement("div");
      cabecalho.className = "recado-cabecalho";

      var nome = document.createElement("strong");
      nome.textContent = r.nome || "Anônimo";

      var data = document.createElement("span");
      data.className = "recado-data";
      data.textContent = formatarData(r.criadoEm);

      cabecalho.appendChild(nome);
      cabecalho.appendChild(data);

      var mensagem = document.createElement("p");
      mensagem.className = "recado-mensagem";
      mensagem.textContent = r.mensagem || "";

      li.appendChild(cabecalho);
      li.appendChild(mensagem);
      lista.appendChild(li);
    });
  }

  function carregarRecados() {
    if (!apiConfigurada()) {
      mostrarMensagemLista("Configure a URL da API no arquivo config.js.");
      return Promise.resolve();
    }

    mostrarMensagemLista("Carregando...");
    return fetch(API_URL + "/recados")
      .then(function (resp) {
        if (!resp.ok) throw new Error("HTTP " + resp.status);
        return resp.json();
      })
      .then(renderizar)
      .catch(function (err) {
        console.error(err);
        mostrarMensagemLista("Erro ao carregar recados (" + err.message + ").");
      });
  }

  function enviarRecado(evento) {
    evento.preventDefault();

    var nome = inputNome.value.trim();
    var mensagem = inputMensagem.value.trim();

    if (!nome || !mensagem) {
      setStatus("Preencha nome e mensagem.", "erro");
      return;
    }
    if (!apiConfigurada()) {
      setStatus("Configure a URL da API no arquivo config.js.", "erro");
      return;
    }

    btnEnviar.disabled = true;
    setStatus("Enviando...");

    fetch(API_URL + "/recados", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nome: nome, mensagem: mensagem })
    })
      .then(function (resp) {
        if (!resp.ok) {
          // A Lambda devolve { erro: "..." } quando a validação falha.
          return resp.json()
            .catch(function () { return {}; })
            .then(function (dados) {
              throw new Error(dados.erro || "HTTP " + resp.status);
            });
        }
        form.reset();
        setStatus("Recado enviado!", "ok");
        return carregarRecados();
      })
      .catch(function (err) {
        console.error(err);
        setStatus("Erro ao enviar recado: " + err.message, "erro");
      })
      .finally(function () {
        btnEnviar.disabled = false;
      });
  }

  form.addEventListener("submit", enviarRecado);
  btnAtualizar.addEventListener("click", carregarRecados);

  carregarRecados();
})();
