#!/usr/bin/env node
// Uso: node tool/kan53/analisar.mjs <coleta.jsonl> <eventos.jsonl>
// Eventos são anotados à mão, um por linha:
// {"tipo":"inicio","em":"2026-11-02T20:01:30-03:00","fonte":"transmissão X","tolS":60}
// {"tipo":"gol","placar":"1-0","em":"2026-11-02T20:20:00-03:00","fonte":"transmissão X","tolS":60}
// {"tipo":"fim","em":"2026-11-02T21:55:00-03:00","fonte":"transmissão X","tolS":60}
import { existsSync, readFileSync } from "node:fs";

import { lerJsonl, resumir } from "./medicao.mjs";

const [coleta, eventos] = process.argv.slice(2);
if (!coleta) throw new Error("Informe o arquivo da coleta.");
const amostras = lerJsonl(readFileSync(coleta, "utf8")).filter((l) => l.t === "amostra");
const anotados = eventos && existsSync(eventos) ? lerJsonl(readFileSync(eventos, "utf8")) : [];
console.log(JSON.stringify(resumir(amostras, anotados), null, 2));
