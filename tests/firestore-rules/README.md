# Testes das Security Rules do Firestore (KAN-22)

Testes de `firestore.rules` contra o **Firestore Emulator local**, usando `node:test` e `fetch` na API REST do emulador. Nenhum recurso real do Firebase é usado (projeto `demo-betfriends`).

| Arquivo | O que valida | Testes |
|---|---|---|
| `firestore.rules.test.mjs` | Permissões do cliente em todas as coleções, sem dependências npm | 67 |
| `backend-admin.test.mjs` | Backend privilegiado (Admin SDK) gravando saldo e transação enquanto o cliente continua bloqueado | 10 |

## Pré-requisitos

- Firebase CLI.
- JDK 21 ou superior para o emulador (no Arch: `/usr/lib/jvm/java-21-openjdk`).
- Node.js 20 ou superior instalado no sistema.
- Emulador do Firestore baixado uma vez: `firebase setup:emulators:firestore`.
- Para `backend-admin.test.mjs`: dependências de `functions/` instaladas (`cd functions && npm ci`). O `firebase-admin` já está declarado em `functions/package.json`.

## Executar

Na raiz do repositório:

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk PATH="$JAVA_HOME/bin:$PATH" \
  firebase emulators:exec --only firestore --project demo-betfriends \
  "$(command -v node) --test --test-concurrency=1 tests/firestore-rules/"
```

- Use o caminho absoluto do Node (`$(command -v node)`): o binário standalone do Firebase CLI usa um Node embutido que não reconhece `--test`.
- `--test-concurrency=1` é obrigatório: os arquivos limpam o emulador e não podem rodar em paralelo.
- Os testes abortam antes de qualquer conexão se `FIRESTORE_EMULATOR_HOST` não estiver definido ou se o projeto não começar com `demo-`.
- O emulador grava `firestore-debug.log` na raiz, que já é ignorado pelo Git.

## Security Rules × autorização das Callable Functions

As Security Rules valem **só para clientes** (SDK Flutter, REST com token de usuário). O Admin SDK usado pelas Callable Functions e pelos jobs **ignora as rules**. Portanto:

- `backend-admin.test.mjs` mostra que o backend tem acesso privilegiado e que o cliente continua restrito. Isso é o que as rules conseguem garantir.
- **Não** comprova que as operações do backend são seguras. Cada Callable Function terá de verificar autenticação (`requireAuth`), autorização (ex.: só participante aceita um desafio), saldo e estado antes de gravar. Isso só poderá ser testado quando as Functions existirem.

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
