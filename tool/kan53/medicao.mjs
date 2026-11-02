// Medição do atraso do plano Free (KAN-53): regras puras, sem rede nem arquivos.
//
// t_evento      quando o fato aconteceu no jogo (anotado à mão, de fonte externa)
// t_sistema     quando o documento mudou no nosso Firestore (`syncedAt`)
// t_observacao  quando o coletor viu a mudança (`Date` da resposta do Firestore)
// t_execucao    início de cada execução da syncMatches (`system/matchSync.lastRunAt`)
//
// `providerLastUpdated` é só registrado: no plano Free ele foi visto igual em
// várias partidas, então não marca um evento de jogo.

const CAMPOS_DO_JOGO = ["status", "homeScore", "awayScore", "result", "startsAtUtc"];

export const PARTIDA_VALIDA = /^footballdata_\d+$/;

/** Só GET, só leitura de uma partida e do estado da sincronização. Lança para qualquer outro acesso. */
export function conferirAcesso(metodo, url, { emulador = null, projeto, partida } = {}) {
  if (metodo !== "GET") throw new Error(`Método recusado: ${metodo}.`);
  const u = new URL(url);
  const host = emulador ?? "firestore.googleapis.com";
  if (u.host !== host) throw new Error(`Host recusado: ${u.host}.`);
  if (emulador === null && u.protocol !== "https:") throw new Error("Protocolo recusado.");
  const raiz = `/v1/projects/${projeto}/databases/(default)/documents`;
  const permitidos = [`${raiz}/matches/${partida}`, `${raiz}/system/matchSync`];
  if (!permitidos.includes(decodeURIComponent(u.pathname))) throw new Error(`Caminho recusado: ${u.pathname}.`);
  if (u.search !== "") throw new Error("Parâmetros recusados.");
}

function valor(campo) {
  if (campo === undefined || campo === null || "nullValue" in campo) return null;
  if ("integerValue" in campo) return Number(campo.integerValue);
  return campo.stringValue ?? campo.timestampValue ?? null;
}

/** Amostra, a partir das respostas brutas do Firestore. Nenhum dado pessoal: só partida e sincronização. */
export function montarAmostra({ partida, sincronizacao, obsLocalMs, dataDoServidor, ambiente }) {
  const f = partida.fields ?? {};
  const s = sincronizacao.fields ?? {};
  const obsServidorMs = Date.parse(dataDoServidor);
  if (Number.isNaN(obsServidorMs)) throw new Error("Resposta sem horário do servidor.");
  return {
    t: "amostra",
    ambiente,
    obsServidor: new Date(obsServidorMs).toISOString(),
    desvioLocalS: (obsLocalMs - obsServidorMs) / 1000,
    status: valor(f.status),
    homeScore: valor(f.homeScore),
    awayScore: valor(f.awayScore),
    result: valor(f.result),
    startsAtUtc: valor(f.startsAtUtc),
    providerLastUpdated: valor(f.providerLastUpdated),
    syncedAt: valor(f.syncedAt),
    updateTime: partida.updateTime ?? null,
    lastRunAt: valor(s.lastRunAt),
    lastRunScope: valor(s.lastRunScope),
    lastSuccessAt: valor(s.lastSuccessAt),
    consecutiveFailures: valor(s.consecutiveFailures),
  };
}

/** Mudanças reais do jogo. Ignora regravação só de `providerLastUpdated` ou `syncedAt`. */
export function detectarMudancas(amostras) {
  const mudancas = [];
  let anterior = null;
  const execucoes = [];
  for (const a of amostras) {
    if (a.lastRunAt && execucoes.at(-1) !== a.lastRunAt) execucoes.push(a.lastRunAt);
    if (anterior !== null) {
      const campos = CAMPOS_DO_JOGO.filter((c) => a[c] !== anterior[c]);
      if (campos.length > 0) {
        const tSistema = a.syncedAt;
        const ultimaSemMudanca = execucoes.filter((e) => tSistema && Date.parse(e) < Date.parse(tSistema) - 60_000).at(-1) ?? null;
        mudancas.push({
          campos,
          status: a.status,
          placar: `${a.homeScore ?? "-"}-${a.awayScore ?? "-"}`,
          tSistema,
          tObservacao: a.obsServidor,
          execucaoAnterior: ultimaSemMudanca,
          providerLastUpdated: a.providerLastUpdated,
        });
      }
    }
    anterior = a;
  }
  return mudancas;
}

const segundos = (fim, inicio) => (Date.parse(fim) - Date.parse(inicio)) / 1000;

/** A mudança que corresponde a um evento anotado, ou `null`. Nunca escolhe por aproximação de horário. */
function mudancaDoEvento(evento, mudancas) {
  switch (evento.tipo) {
    case "inicio":
      return mudancas.find((m) => m.campos.includes("status") && m.status === "EM_ANDAMENTO") ?? null;
    case "fim":
      return mudancas.find((m) => m.campos.includes("status") && m.status === "FINALIZADA") ?? null;
    case "gol":
      return mudancas.find((m) => m.placar === evento.placar && (m.campos.includes("homeScore") || m.campos.includes("awayScore"))) ?? null;
    default:
      return null;
  }
}

/**
 * Atraso de cada evento. O atraso do provedor é um intervalo, porque só
 * consultamos a cada execução: entre a última execução que ainda não trouxe o
 * evento e a que trouxe. A tolerância da anotação (`tolS`) é somada ao resultado.
 */
export function calcularAtrasos(eventos, mudancas) {
  return eventos.map((e) => {
    const m = mudancaDoEvento(e, mudancas);
    const base = { tipo: e.tipo, placar: e.placar ?? null, tEvento: e.em, fonte: e.fonte ?? null, tolS: e.tolS ?? null };
    if (m === null) return { ...base, situacao: "sem-mudanca-correspondente" };
    return {
      ...base,
      situacao: "medido",
      tSistema: m.tSistema,
      tObservacao: m.tObservacao,
      atrasoAteSistemaS: segundos(m.tSistema, e.em),
      atrasoProvedorMinS: m.execucaoAnterior === null ? null : Math.max(0, segundos(m.execucaoAnterior, e.em)),
      atrasoProvedorMaxS: segundos(m.tSistema, e.em),
      atrasoDaObservacaoS: segundos(m.tObservacao, m.tSistema),
    };
  });
}

/** Resumo. Só é evidência real com amostras de produção e pelo menos um evento medido. */
export function resumir(amostras, eventos, ambientes = new Set(amostras.map((a) => a.ambiente))) {
  const mudancas = detectarMudancas(amostras);
  const atrasos = calcularAtrasos(eventos, mudancas);
  const medidos = atrasos.filter((a) => a.situacao === "medido");
  const desvios = amostras.map((a) => a.desvioLocalS).sort((x, y) => x - y);
  return {
    amostras: amostras.length,
    ambientes: [...ambientes],
    evidenciaReal: ambientes.size === 1 && ambientes.has("producao") && medidos.length > 0,
    desvioLocalMedianoS: desvios.length === 0 ? null : desvios[Math.floor(desvios.length / 2)],
    falhasMaximasDaSincronizacao: Math.max(0, ...amostras.map((a) => a.consecutiveFailures ?? 0)),
    mudancas,
    atrasos,
  };
}

/** Lê JSONL ignorando só a última linha, se estiver incompleta por interrupção. */
export function lerJsonl(texto) {
  const linhas = texto.split("\n").filter((l) => l.trim() !== "");
  return linhas.flatMap((l, i) => {
    try {
      return [JSON.parse(l)];
    } catch (e) {
      if (i === linhas.length - 1) return [];
      throw e;
    }
  });
}
