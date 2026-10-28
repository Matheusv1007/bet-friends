# Testes de integração com os emuladores Firebase

## `user_profile_emulator_test.dart` (KAN-32)

Valida `FirestoreUserProfileRepository` e `UserProfileService` num dispositivo Android contra o **Auth Emulator**, o **Firestore Emulator** e as Security Rules reais (`firestore.rules`). Usa um `FirebaseApp` separado, configurado para o projeto fictício `demo-betfriends`. O app padrão, ligado ao projeto real, não é usado pelo teste.

Os dados são criados antes por `support/seed_emulators.mjs` com o Admin SDK, porque o app não pode criar `users/{uid}`:

| Conta (só no emulador) | Documento `users/{uid}` |
|---|---|
| `uidAna` / `ana@example.com` | Perfil completo do schema v2.0 (com carteira) |
| `uidBia` / `bia@example.com` | Perfil completo (usado como "outro usuário") |
| `uidCaio` / `caio@example.com` | Perfil completo, alterado só pelos testes de edição do nome |
| `uidSemPerfil` / `semperfil@example.com` | Nenhum |
| `uidInvalido` / `invalido@example.com` | Documento fora do schema (sem `username`) |

## `perfil_screen_emulator_test.dart` (KAN-28)

Abre a `PerfilScreen` com o `UserProfileService` real, no mesmo ambiente, e verifica o que a tela exibe: nome e username de `uidBia`, perfil inexistente (`uidSemPerfil`), documento fora do schema (`uidInvalido`), sem sessão e Firestore inacessível.

## `editar_nome_emulator_test.dart` (KAN-29)

Edita o nome de `uidCaio` pela tela e confere no Firestore que só `displayName` e `updatedAt` mudaram. Também verifica que, sem conexão, a gravação falha em tempo finito com `unavailable` e não grava, e que o perfil de outro UID não pode ser alterado.

## Pré-requisitos

- Emulador Android em execução (`flutter emulators --launch Pixel_10_Pro`). O teste acessa os emuladores do host por `10.0.2.2`.
- JDK 21+, Firebase CLI e Firestore Emulator, como em `tests/firestore-rules/README.md`.
- `cd functions && npm ci`, para o `firebase-admin` usado pelo seed.

## Executar

Na raiz do repositório:

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk PATH="$JAVA_HOME/bin:$PATH" \
  firebase emulators:exec --only auth,firestore --project demo-betfriends \
  "$(command -v node) integration_test/support/seed_emulators.mjs && \
   $(command -v flutter) test integration_test/ -d emulator-5554"
```

Os arquivos rodam em sequência na mesma sessão dos emuladores. Cada um altera só a própria conta (`uidAna` na KAN-32, `uidCaio` na KAN-29); a tela da KAN-28 usa `uidBia`, que ninguém altera.

O seed aborta se `FIRESTORE_EMULATOR_HOST`/`FIREBASE_AUTH_EMULATOR_HOST` não estiverem definidos ou se o projeto não começar com `demo-`. O teste Dart verifica que o app usado é `demo-*`.

Estes testes **não** rodam com `flutter test` comum: precisam de um dispositivo e dos emuladores.
