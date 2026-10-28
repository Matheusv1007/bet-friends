# Testes das Security Rules do Firestore (KAN-22)

Testes de `firestore.rules` contra o **Firestore Emulator local**, usando `node:test` e `fetch` na API REST do emulador. Nenhuma dependência npm é necessária, e nenhum recurso real do Firebase é usado (projeto `demo-betfriends`).

## Pré-requisitos

- Firebase CLI.
- JDK 21 ou superior para o emulador (no Arch: `/usr/lib/jvm/java-21-openjdk`).
- Node.js 20 ou superior instalado no sistema.
- Emulador do Firestore baixado uma vez: `firebase setup:emulators:firestore`.

## Executar

Na raiz do repositório:

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk PATH="$JAVA_HOME/bin:$PATH" \
  firebase emulators:exec --only firestore --project demo-betfriends \
  "$(command -v node) --test tests/firestore-rules/"
```

Use o caminho absoluto do Node (`$(command -v node)`): o binário standalone do Firebase CLI usa um Node embutido que não reconhece `--test`.

O emulador grava `firestore-debug.log` na raiz, que já é ignorado pelo Git.

## Consultas que as regras aceitam

O Firestore só autoriza uma consulta se o filtro **garantir** que todo resultado é permitido. Por isso o app precisa usar exatamente estes filtros:

| Coleção | Leitura de documento | Consulta (lista) aceita |
|---|---|---|
| `users` | `get` do próprio `users/{uid}` | nenhuma |
| `usernames` | nenhuma | nenhuma |
| `friendships` | participante | `where('participants', arrayContains: uid)` |
| `matches` | qualquer usuário autenticado | qualquer filtro |
| `challenges` | participante | `where('participants', arrayContains: uid)` |
| `betCoinTransactions` | dono (`userId`) | `where('userId', isEqualTo: uid)` |

Consultas por `userAId`, `challengedId`, `challengerId` ou sem filtro são negadas, mesmo que os resultados pertençam ao usuário. Filtros extras, como `status` ou ordenação, podem ser combinados com os filtros acima, mas exigirão os índices listados em `docs/firestore-schema.md` §6.
