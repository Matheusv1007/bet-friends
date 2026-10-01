import { setGlobalOptions } from "firebase-functions/options";

/** Mesma região do Firestore (ver firebase.json). O app Flutter deve usar a mesma. */
export const REGION = "southamerica-east1";

setGlobalOptions({
  region: REGION,
  maxInstances: 10,
});
