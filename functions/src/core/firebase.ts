import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

if (getApps().length === 0) {
  initializeApp();
}

/** Firestore com privilégios de admin: ignora as security rules. */
export const db = getFirestore();
