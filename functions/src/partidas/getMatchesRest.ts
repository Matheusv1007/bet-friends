import { onRequest } from "firebase-functions/https";

import { db } from "../core/firebase";
import { COLECAO_DE_PARTIDAS, matchDoDocumento } from "./matchFirestore";

/**
 * Endpoint REST GET para atender à atividade acadêmica (Consumo de API REST GET).
 *
 * Retorna dados normalizados de partidas do Brasileirão em formato JSON a partir do Firestore.
 * Não expõe nenhuma credencial externa e não chama a Football-Data.org durante a requisição do cliente.
 */
export const getMatchesRest = onRequest({ cors: true }, async (req, res) => {
  // 1. Apenas aceita método HTTP GET
  if (req.method !== "GET") {
    res.status(405).json({
      error: "Método não permitido. Utilize o método HTTP GET.",
    });
    return;
  }

  try {
    const limitParam = Number(req.query.limit);
    const limit = Number.isSafeInteger(limitParam) && limitParam > 0 && limitParam <= 50 ? limitParam : 15;
    const competitionCode = typeof req.query.competition === "string" ? req.query.competition.toUpperCase() : "BSA";

    const snapshot = await db
      .collection(COLECAO_DE_PARTIDAS)
      .where("competitionCode", "==", competitionCode)
      .orderBy("startsAtUtc", "asc")
      .limit(limit)
      .get();

    const matches = snapshot.docs.map((doc) => {
      try {
        const m = matchDoDocumento(doc.id, doc.data());
        return {
          id: m.id,
          competitionCode: m.competitionCode,
          season: m.season,
          matchday: m.matchday,
          startsAtUtc: m.startsAtUtc.toISOString(),
          status: m.status,
          homeTeam: m.homeTeam,
          awayTeam: m.awayTeam,
          homeScore: m.homeScore,
          awayScore: m.awayScore,
          result: m.result,
        };
      } catch {
        const d = doc.data();
        return {
          id: doc.id,
          competitionCode: d.competitionCode ?? "BSA",
          season: d.season ?? 2026,
          matchday: d.matchday ?? null,
          startsAtUtc: d.startsAtUtc?.toDate?.()?.toISOString() ?? null,
          status: d.status ?? "AGENDADA",
          homeTeam: d.homeTeam ?? { name: "Mandante", shortName: "Mandante" },
          awayTeam: d.awayTeam ?? { name: "Visitante", shortName: "Visitante" },
          homeScore: d.homeScore ?? null,
          awayScore: d.awayScore ?? null,
          result: d.result ?? null,
        };
      }
    });

    res.set("Content-Type", "application/json; charset=utf-8");
    res.set("Cache-Control", "public, max-age=60, s-maxage=120");
    res.status(200).json({
      success: true,
      total: matches.length,
      competition: competitionCode,
      matches,
    });
  } catch {
    res.status(500).json({
      success: false,
      error: "Erro interno ao processar a consulta de partidas no servidor.",
    });
  }
});
