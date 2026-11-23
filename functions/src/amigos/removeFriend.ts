import { HttpsError } from "firebase-functions/https";

import { authedCallable } from "../core/callable";
import { db } from "../core/firebase";
import { requireObject } from "../core/validation";
import { removerAmizade, ResultadoRemocaoAmizade } from "./remocaoAmizade";

export const removeFriend = authedCallable<
  { readonly friendshipId: string },
  ResultadoRemocaoAmizade
>(
  (data, auth) => removerAmizade(db, auth.uid, data.friendshipId),
  {
    parse: (raw) => {
      const data = requireObject(raw);
      const friendshipId = typeof data.friendshipId === "string" ? data.friendshipId.trim() : "";
      if (!friendshipId || friendshipId.includes("/") || friendshipId === "." || friendshipId === ".."
        || Buffer.byteLength(friendshipId, "utf8") > 1500 || /^__.*__$/.test(friendshipId)) {
        throw new HttpsError("invalid-argument", 'Campo "friendshipId" deve ser um identificador de amizade válido.', {
          motivo: "uid-invalido",
        });
      }
      return { friendshipId };
    },
  },
);
