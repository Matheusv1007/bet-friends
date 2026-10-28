# Callable Functions - Estrutura do Backend

## 1 - Objetivo

Este documento descreve a camada de backend criada na KAN-18 para operações sensíveis do BetFriends.

Regras de negócio que mexem em saldo, desafios ou dados de outros usuários devem rodar em Callable Functions, nunca direto do app.

## 2 - Configuração

Código:

`functions/` (TypeScript, Node 22, firebase-functions v7)

Região:

`southamerica-east1` (mesma do Firestore)

A região está definida em `functions/src/config.ts` e em `lib/services/functions/functions_service.dart`. As duas precisam ser iguais.

## 3 - Estrutura

```text
functions/src/
  index.ts            exporta as funções publicadas
  config.ts           região e opções globais
  core/firebase.ts    firebase-admin + Firestore (db)
  core/auth.ts        requireAuth: exige usuário logado e extrai uid/email
  core/validation.ts  validação do payload (requireObject, requireString, requireInt)
  core/segredos.ts    segredos do backend (FOOTBALL_DATA_TOKEN) e leitura segura
  core/callable.ts    authedCallable: base de toda função autenticada
  system/ping.ts      systemPing: chamada técnica
```

## 4 - Criando uma nova função

```ts
import { authedCallable } from "../core/callable";
import { requireInt, requireObject, requireString } from "../core/validation";

export const createChallenge = authedCallable(
  async (data, auth) => {
    // auth.uid é confiável: vem do token verificado pelo Firebase.
    // Aplicar regras de negócio aqui (ex.: checar saldo no Firestore via db).
    return { ok: true };
  },
  {
    parse: (raw) => {
      const data = requireObject(raw);
      return {
        matchId: requireString(data, "matchId"),
        amount: requireInt(data, "amount", { min: 1 }),
      };
    },
  },
);
```

Depois, exportar em `functions/src/index.ts` e adicionar o nome em `CallableNames` no Flutter.

Nunca confiar em uid, saldo ou papel enviados no payload: usar sempre `auth`.

## 5 - Chamando no Flutter

```dart
final result = await FunctionsService().call('createChallenge', {
  'matchId': '123',
  'amount': 10,
});
```

Erros do backend chegam como `FunctionsException` com `code` (ex.: `unauthenticated`, `invalid-argument`).

## 6 - Rodando localmente

```bash
cd functions
npm install
npm test          # testes unitários
npm run serve     # emuladores de Auth + Functions
```

App apontando para o emulador de Functions e executando a chamada técnica após o login:

```bash
flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true --dart-define=FUNCTIONS_SMOKE_TEST=true
```

O console mostra `[FunctionsSmokeTest] OK: PingResult(uid: ...)` quando o uid recebido pelo backend é o mesmo do usuário logado.

Em dispositivo físico, informar o IP da máquina com `--dart-define=FUNCTIONS_EMULATOR_HOST=<ip>`.

O emulador responde em HTTP sem TLS, que o Android bloqueia por padrão. Por isso `android/app/src/debug/AndroidManifest.xml` libera `usesCleartextTraffic` apenas em debug. Sem isso, a chamada falha com `FunctionsException (unavailable)`.

## 7 - Deploy

```bash
firebase deploy --only functions
```

O deploy de Functions exige o projeto Firebase no plano Blaze.

## 8 - Segredos (KAN-21)

Credenciais de serviços externos ficam **só no backend**, no Google Secret Manager. Nunca no app Flutter, em arquivo versionado, no Jira ou em logs (RN-SEC-003, RN-SEC-005, RNF-004).

| Segredo | Uso |
|---|---|
| `FOOTBALL_DATA_TOKEN` | Token da Football-Data.org, usado pelo Adapter do provedor (KAN-44) |

### 8.1 - Usando numa função

A função declara o segredo nas opções e lê o valor só em tempo de execução, com `lerTokenFootballData()`:

```ts
import { FOOTBALL_DATA_TOKEN, lerTokenFootballData } from "../core/segredos";

export const sincronizarPartidas = onSchedule({ schedule: "...", secrets: [FOOTBALL_DATA_TOKEN] }, async () => {
  const token = lerTokenFootballData(); // nunca logar nem devolver ao app
});
```

Em produção, só as funções que declaram `secrets: [FOOTBALL_DATA_TOKEN]` recebem o valor. `lerTokenFootballData()` lança `ErroDeCredencial` (`credencial-ausente` ou `credencial-invalida`) sem incluir o valor na mensagem.

### 8.2 - Configurando em produção

Exige o plano Blaze (Secret Manager).

```bash
firebase functions:secrets:set FOOTBALL_DATA_TOKEN   # o CLI pede o valor sem ecoar
firebase deploy --only functions
```

### 8.3 - Rotação (ex.: token exposto)

1. Gerar um novo token no painel da Football-Data.org (o anterior deixa de funcionar).
2. `firebase functions:secrets:set FOOTBALL_DATA_TOKEN` com o novo valor (cria uma nova versão).
3. `firebase deploy --only functions` para as funções usarem a nova versão.
4. `firebase functions:secrets:prune` para destruir as versões antigas que não estão em uso.

### 8.4 - No emulador

Criar `functions/.secret.local` (já ignorado pelo git e pelo deploy via `*.local`):

```text
FOOTBALL_DATA_TOKEN=<token>
```

Diferente da produção, o emulador entrega os valores de `.secret.local` a todas as funções, mesmo às que não declaram o segredo. Não use isso como prova de isolamento.
