#!/usr/bin/env node
// Coletor passivo da KAN-53. Só lê `matches/{partida}` e `system/matchSync`;
// nunca chama a Football-Data nem grava no Firebase. Uso em tool/kan53/README.md.
import { appendFileSync, mkdirSync } from "node:fs";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import path from "node:path";
import { parseArgs } from "node:util";

import { PARTIDA_VALIDA, conferirAcesso, montarAmostra } from "./medicao.mjs";

const { values: a } = parseArgs({
  options: {
    partida: { type: "string" },
    intervalo: { type: "string", default: "30" },
    horas: { type: "string", default: "5" },
    saida: { type: "string", default: path.join(homedir(), ".local/share/betfriends-kan53") },
    "firebase-tools": { type: "string", default: process.env.FIREBASE_TOOLS_DIR ?? "" },
    ciclos: { type: "string" },
  },
});

if (!PARTIDA_VALIDA.test(a.partida ?? "")) throw new Error("Informe --partida footballdata_<id>.");
const intervaloS = Number(a.intervalo);
if (!(intervaloS >= 15 && intervaloS <= 300)) throw new Error("--intervalo deve ir de 15 a 300 segundos.");

const emulador = process.env.FIRESTORE_EMULATOR_HOST ?? null;
const projeto = emulador ? process.env.GCLOUD_PROJECT : "betfriends-unirv-2026";
if (emulador && !projeto?.startsWith("demo-")) throw new Error("No emulador, use um projeto demo-*.");
const ambiente = emulador ? "emulador" : "producao";

async function cabecalhos() {
  if (emulador) return { Authorization: "Bearer owner" };
  if (!a["firebase-tools"]) throw new Error("Informe --firebase-tools ou FIREBASE_TOOLS_DIR.");
  const exigir = createRequire(path.join(a["firebase-tools"], "package.json"));
  const ft = (m) => exigir(`./lib/${m}`);
  const conta = ft("auth").getGlobalDefaultAccount();
  await ft("requireAuth").requireAuth({ user: conta.user, tokens: conta.tokens, project: projeto });
  return { Authorization: `Bearer ${await ft("apiv2").getAccessToken()}`, "x-goog-user-project": projeto };
}

const base = emulador
  ? `http://${emulador}/v1/projects/${projeto}/databases/(default)/documents`
  : `https://firestore.googleapis.com/v1/projects/${projeto}/databases/(default)/documents`;

async function ler(caminho, h) {
  const url = `${base}/${caminho}`;
  conferirAcesso("GET", url, { emulador, projeto, partida: a.partida });
  const r = await fetch(url, { method: "GET", headers: h, signal: AbortSignal.timeout(20_000) });
  if (!r.ok) throw new Error(`HTTP ${r.status} em ${caminho.split("/")[0]}`);
  return { corpo: await r.json(), data: r.headers.get("date") };
}

mkdirSync(a.saida, { recursive: true, mode: 0o700 });
const arquivo = path.join(a.saida, `${ambiente}-${a.partida}.jsonl`);
const gravar = (o) => appendFileSync(arquivo, `${JSON.stringify(o)}\n`, { mode: 0o600 });

const fim = Date.now() + Number(a.horas) * 3600_000;
const ciclos = a.ciclos === undefined ? Infinity : Number(a.ciclos);
gravar({ t: "inicio", ambiente, partida: a.partida, intervaloS, em: new Date().toISOString() });
console.log(`Coletando ${a.partida} (${ambiente}) a cada ${intervaloS} s em ${arquivo}. Ctrl+C encerra.`);

let parar = false;
process.on("SIGINT", () => { parar = true; });
process.on("SIGTERM", () => { parar = true; });

let anterior = null;
for (let i = 0; i < ciclos && !parar && Date.now() < fim; i++) {
  try {
    const h = await cabecalhos();
    const partida = await ler(`matches/${a.partida}`, h);
    const sincronizacao = await ler("system/matchSync", h);
    const amostra = montarAmostra({
      partida: partida.corpo,
      sincronizacao: sincronizacao.corpo,
      obsLocalMs: Date.now(),
      // O Firestore Emulator não envia `Date`; em produção, a falta dele é erro
      dataDoServidor: partida.data ?? (emulador ? new Date().toUTCString() : null),
      ambiente,
    });
    gravar(amostra);
    const atual = `${amostra.status} ${amostra.homeScore ?? "-"}-${amostra.awayScore ?? "-"}`;
    if (atual !== anterior) console.log(`${amostra.obsServidor} ${atual}`);
    anterior = atual;
  } catch (e) {
    // Falha de leitura não é repetida em rajada: a próxima tentativa respeita o intervalo
    gravar({ t: "erro", em: new Date().toISOString(), motivo: e.message });
    console.error(`Falha nesta leitura: ${e.message}`);
  }
  if (i + 1 < ciclos && !parar) await new Promise((r) => setTimeout(r, intervaloS * 1000));
}
gravar({ t: "fim", em: new Date().toISOString() });
console.log("Coleta encerrada.");
