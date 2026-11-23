// Proxy TCP entre o app e o Firestore Emulator para simular a queda e o
// retorno da conexão em integration_test/modo_offline_emulator_test.dart
// (KAN-24). `disableNetwork()` do Firestore não serve para isso: ele só
// desliga os listeners e a fila de escrita; transações continuam chegando ao
// servidor.
//
// O teste aponta o Firestore para PROXY_PORT e controla a conexão por HTTP:
// GET /offline derruba as conexões abertas e recusa novas; GET /online volta
// a encaminhar. Só encaminha para o emulador local; ver integration_test/README.md.

import net from "node:net";
import http from "node:http";

const HOST = "127.0.0.1";
const DESTINO = Number(process.env.FIRESTORE_EMULATOR_HOST?.split(":")[1] ?? 8080);
const PROXY_PORT = 8180;
const CONTROLE_PORT = 8181;

let online = true;
const conexoes = new Set();

const proxy = net.createServer((cliente) => {
  if (!online) return cliente.destroy();
  const emulador = net.connect(DESTINO, HOST);
  const par = [cliente, emulador];
  par.forEach((s) => {
    conexoes.add(s);
    s.on("error", () => par.forEach((x) => x.destroy()));
    s.on("close", () => {
      conexoes.delete(s);
      par.forEach((x) => x.destroy());
    });
  });
  cliente.pipe(emulador).pipe(cliente);
});

const controle = http.createServer((req, res) => {
  if (req.url === "/offline") {
    online = false;
    conexoes.forEach((s) => s.destroy());
  } else if (req.url === "/online") {
    online = true;
  } else {
    res.writeHead(404).end();
    return;
  }
  console.log(`[proxy] ${online ? "online" : "offline"}`);
  res.end(online ? "online" : "offline");
});

proxy.listen(PROXY_PORT, HOST);
controle.listen(CONTROLE_PORT, HOST);
console.log(`[proxy] ${HOST}:${PROXY_PORT} -> ${HOST}:${DESTINO}; controle em ${HOST}:${CONTROLE_PORT}`);
