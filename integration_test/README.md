# Testes de integração com os emuladores Firebase

## `user_profile_emulator_test.dart` (KAN-32)

Valida `FirestoreUserProfileRepository` e `UserProfileService` num dispositivo Android contra o **Auth Emulator**, o **Firestore Emulator** e as Security Rules reais (`firestore.rules`). Usa um `FirebaseApp` separado, configurado para o projeto fictício `demo-betfriends`. O app padrão, ligado ao projeto real, não é usado pelo teste.

Os dados são criados antes por `support/seed_emulators.mjs` com o Admin SDK, porque o app não pode criar `users/{uid}`:

| Conta (só no emulador) | Documento `users/{uid}` |
|---|---|
| `uidAna` / `ana@example.com` | Perfil completo do schema v2.0 (com carteira) |
| `uidBia` / `bia@example.com` | Perfil completo (usado como "outro usuário") |
| `uidCaio` / `caio@example.com` | Perfil completo, alterado só pelos testes de edição do nome |
| `uidDani` / `dani@example.com` | Perfil completo, usado só pelos testes de modo offline |
| `uidSemPerfil` / `semperfil@example.com` | Nenhum |
| `uidInvalido` / `invalido@example.com` | Documento fora do schema (sem `username`) |

## `perfil_screen_emulator_test.dart` (KAN-28)

Abre a `PerfilScreen` com o `UserProfileService` real, no mesmo ambiente, e verifica o que a tela exibe: nome e username de `uidBia`, perfil inexistente (`uidSemPerfil`), documento fora do schema (`uidInvalido`), sem sessão e Firestore inacessível.

## `editar_nome_emulator_test.dart` (KAN-29)

Edita o nome de `uidCaio` pela tela e confere no Firestore que só `displayName` e `updatedAt` mudaram. Também verifica que, sem conexão, a gravação falha em tempo finito com `unavailable` e não grava, e que o perfil de outro UID não pode ser alterado.

## `modo_offline_emulator_test.dart` (KAN-24)

Derruba e restabelece a conexão entre o app e o Firestore Emulator com `support/proxy_conexao.mjs`, um proxy TCP local (porta 8180, controle HTTP em 8181) que só encaminha para o emulador. O cache persistente fica ligado, como no app. Verifica que:

- sem conexão e sem cache, a leitura informa `unavailable`;
- sem conexão, com cache, o último perfil conhecido é exibido como "do cache";
- alterar o perfil offline falha, não toca o cache, não deixa escrita pendente e nada é gravado quando a conexão volta;
- depois do retorno da conexão, uma nova ação do usuário grava normalmente;
- a tela de Perfil avisa a falta de conexão, bloqueia a edição e volta ao normal ao reconectar.

Um teste de controle mostra o motivo da política: um `update` direto offline seria enviado sozinho ao reconectar.

`disableNetwork()` não é usado para simular a queda: ele não impede transações de chegarem ao servidor.

## `criar_perfil_emulator_test.dart` (KAN-32)

Cria o perfil pela Callable `createUserProfile` (KAN-31) com o `UserProfileService` real, contra o **Functions Emulator**, além de Auth e Firestore. As contas são criadas pelo próprio teste no Auth Emulator, como a tela de cadastro fará (KAN-25); não dependem do seed. Verifica que:

- o perfil criado é `users/{uid}` do UID autenticado, com nome, username, e-mail, carteira de 1.000 e um único `INITIAL_BALANCE`, e que o app lê o mesmo documento;
- repetir a chamada, inclusive em paralelo, não duplica perfil nem carteira (`criado == false`);
- username de outro usuário → `usernameUnavailable`; perfil com outro username → `alreadyExists`; formato inválido → `invalidData`; sem sessão → `unauthenticated` no serviço e no backend;
- uma conta do Auth sem perfil (primeira tentativa recusada) é recuperada ao repetir;
- o cliente continua sem conseguir gravar `users`, `usernames` e `betCoinTransactions` diretamente;
- Functions inacessível → `unavailable`; função inexistente → `not-found`;
- leitura, observação e edição do nome continuam funcionando no perfil criado.

Os testes do arquivo rodam em ordem: os grupos B a D usam a conta criada no grupo A.

O `FirebaseApp` deste arquivo usa uma API key fictícia no formato do Firebase, porque o SDK de Functions no Android recusa chaves como `demo-api-key`. Não é uma credencial.

## Pré-requisitos

- Emulador Android em execução (`flutter emulators --launch Pixel_10_Pro`). O teste acessa os emuladores do host por `10.0.2.2`.
- JDK 21+, Firebase CLI e Firestore Emulator, como em `tests/firestore-rules/README.md`.
- `cd functions && npm ci`, para o `firebase-admin` usado pelo seed.
- Para `criar_perfil_emulator_test.dart`: `cd functions && npm run build`, para o Functions Emulator carregar `functions/lib/`.
- O Functions Emulator precisa rodar o Firebase CLI com o Node do sistema (22 ou superior). O binário standalone (`/usr/local/bin/firebase`) usa um Node 20 embutido, que não carrega o `firebase-admin` 14 (`ERR_REQUIRE_ESM` em `jose`) e deixa o emulador sem funções (`not-found`). O comando abaixo chama o mesmo CLI já instalado em `~/.cache/firebase/tools` com o Node do sistema.

## Executar

Na raiz do repositório:

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk PATH="$JAVA_HOME/bin:$PATH" \
  node ~/.cache/firebase/tools/lib/node_modules/firebase-tools/lib/bin/firebase.js \
  emulators:exec --only auth,firestore,functions --project demo-betfriends \
  "$(command -v node) integration_test/support/seed_emulators.mjs && \
   { $(command -v node) integration_test/support/proxy_conexao.mjs & P=\$!; \
     $(command -v flutter) test integration_test/ -d emulator-5554; R=\$?; kill \$P; exit \$R; }"
```

O proxy só é necessário para `modo_offline_emulator_test.dart`; os demais arquivos funcionam com o comando sem ele. O Functions Emulator só é necessário para `criar_perfil_emulator_test.dart`.

Os arquivos rodam em sequência na mesma sessão dos emuladores. Cada um altera só a própria conta (`uidAna` na KAN-32, `uidCaio` na KAN-29, `uidDani` na KAN-24); a tela da KAN-28 usa `uidBia`, que ninguém altera.

O seed aborta se `FIRESTORE_EMULATOR_HOST`/`FIREBASE_AUTH_EMULATOR_HOST` não estiverem definidos ou se o projeto não começar com `demo-`. O teste Dart verifica que o app usado é `demo-*`.

Estes testes **não** rodam com `flutter test` comum: precisam de um dispositivo e dos emuladores.
