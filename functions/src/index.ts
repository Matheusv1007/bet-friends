// A configuração global precisa ser carregada antes das definições das funções.
import "./config";
import "./core/firebase";

export { systemPing } from "./system/ping";
export { createUserProfile } from "./perfil/createUserProfile";
export { resolveLoginEmail } from "./perfil/resolveLoginEmail";
export { deleteAccount } from "./perfil/deleteAccount";
export { claimRecoveryBonus } from "./betcoins/claimRecoveryBonus";
export { syncMatches } from "./partidas/syncMatches";
export { searchUsers } from "./perfil/searchUsers";
export { sendFriendRequest } from "./amigos/sendFriendRequest";
export { acceptFriendRequest } from "./amigos/acceptFriendRequest";
export { rejectFriendRequest } from "./amigos/rejectFriendRequest";
export { getFriendRequests } from "./amigos/getFriendRequests";
export { getFriends } from "./amigos/getFriends";
export { removeFriend } from "./amigos/removeFriend";
export { createChallenge } from "./desafios/createChallenge";
export { acceptChallenge } from "./desafios/acceptChallenge";
export { rejectChallenge } from "./desafios/rejectChallenge";
export { cancelChallenge } from "./desafios/cancelChallenge";
