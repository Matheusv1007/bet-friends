// A configuração global precisa ser carregada antes das definições das funções.
import "./config";
import "./core/firebase";

export { systemPing } from "./system/ping";
export { createUserProfile } from "./perfil/createUserProfile";
export { claimRecoveryBonus } from "./betcoins/claimRecoveryBonus";
export { syncMatches } from "./partidas/syncMatches";
export { getMatchesRest } from "./partidas/getMatchesRest";
export { searchUsers } from "./perfil/searchUsers";
export { sendFriendRequest } from "./amigos/sendFriendRequest";
export { acceptFriendRequest } from "./amigos/acceptFriendRequest";
export { createChallenge } from "./desafios/createChallenge";
export { acceptChallenge } from "./desafios/acceptChallenge";
