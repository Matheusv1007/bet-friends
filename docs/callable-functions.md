# Callable Functions - Estrutura do Backend

## 1 - Objetivo

Este documento descreve a camada de backend criada na KAN-18 para operações sensíveis do BetFriends.

Regras de negócio que mexem em saldo, desafios ou dados de outros usuários devem rodar em Callable Functions, nunca direto do app.

## 2 - Configuração

Código:

`functions/` (TypeScript, Node 22, firebase-functions v7). A versão major do Node está em `functions/.nvmrc`; como usá-la junto com o Firebase CLI está na seção 9.

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
  partidas/syncMatches.ts  syncMatches: sincronização agendada das partidas (KAN-50, seção 10)
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

Com o Node 22 no PATH (seção 9):

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

Com o Node 22 no PATH (seção 9):

```bash
npx firebase-tools@15.32.1 deploy --only functions --project betfriends-unirv-2026
```

O deploy de Functions exige o projeto Firebase no plano Blaze. Informe sempre `--project` e `--only`: o `.firebaserc` só tem o projeto de produção.

**Situação em 01/11/2026:** o projeto está no plano **Blaze**, com `systemPing`, `createUserProfile`, `claimRecoveryBonus` e `syncMatches` publicadas. Pré-requisitos seguidos no primeiro deploy, válidos como referência para os próximos:

1. Ativar o plano Blaze, com alerta de orçamento (decisão do Proprietário do projeto).
2. Garantir a permissão de deploy. As Callables gen 2 rodam no Cloud Run, e o deploy libera a invocação pública do serviço, o que exige `run.services.setIamPolicy`. O papel Editor não tem essa permissão. O deploy deve ser feito pelo Proprietário, ou por uma conta com um papel que a inclua (ex.: Cloud Run Admin ou Cloud Functions Admin).
3. Aceitar, no primeiro deploy, a política de limpeza de imagens do Artifact Registry.

As Security Rules são publicadas separadamente e não exigem o Blaze (`npx firebase-tools@15.32.1 deploy --only firestore:rules --project betfriends-unirv-2026`). Foram publicadas em 29/10/2026, depois de 67/67 testes unitários e 226/226 do backend + rules no emulador.

## 8 - Segredos (KAN-21)

Credenciais de serviços externos ficam **só no backend**, no Google Secret Manager. Nunca no app Flutter, em arquivo versionado, no Jira ou em logs (RN-SEC-003, RN-SEC-005, RNF-004).

| Segredo | Uso |
|---|---|
| `FOOTBALL_DATA_TOKEN` | Token da Football-Data.org, usado pelo Adapter do provedor (KAN-44) na função agendada `syncMatches` (KAN-50) |

### 8.1 - Usando numa função

A função declara o segredo nas opções e lê o valor só em tempo de execução, com `lerTokenFootballData()` (o Adapter já faz essa leitura; exemplo real em `functions/src/partidas/syncMatches.ts`):

```ts
import { FOOTBALL_DATA_TOKEN, lerTokenFootballData } from "../core/segredos";

export const minhaFuncao = onSchedule({ schedule: "...", secrets: [FOOTBALL_DATA_TOKEN] }, async () => {
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

### 8.3 - Rotação e Revogação do Token Exposto (KAN-102; Auditoria Técnica 10/05/2026, RN-SEC-005, RNF-004)

1. **Procedimento Operacional de Rotação:**
   - Gerar uma nova credencial no painel da Football-Data.org. O token anterior é invalidado no provedor e deixa de funcionar.
   - Definir o novo segredo no backend: `firebase functions:secrets:set FOOTBALL_DATA_TOKEN` (o CLI solicita o valor sem ecoar no terminal).
   - Implantar as Cloud Functions: `firebase deploy --only functions --project betfriends-unirv-2026` para que utilizem a nova versão do segredo.
   - Destruir versões antigas/revogadas no Secret Manager: `firebase functions:secrets:prune --project betfriends-unirv-2026`.

2. **Registro de Segurança para a Equipe:**
   - **Credencial antiga invalidada:** A credencial identificada na auditoria de 10/05/2026 como exposta no histórico do repositório (`lib/services/api/partidas_service.dart`) e embutida no APK anterior está formalmente **revogada e descontinuada**. Ela não deve ser utilizada em nenhum ambiente (desenvolvimento, homologação ou produção).
   - **Isolamento de Credenciais (KAN-21 / RN-SEC-003, RN-SEC-005):** Nenhuma credencial do provedor de futebol é adicionada ao código Flutter nem a qualquer arquivo versionado no repositório. Arquivos locais de segredos (`functions/.secret.local`, `.env*`, `*.local`) estão protegidos no `.gitignore`.
   - **Consumo Exclusivo via Firestore (KAN-42 / RNF-005):** O aplicativo Flutter consome exclusivamente a coleção `matches` do Cloud Firestore sincronizada pela Cloud Function agendada `syncMatches`, sem chamadas diretas do cliente à Football-Data.org.
   - **Proteção em Registros Públicos:** Nenhum valor secreto de credencial pode ser registrado em texto claro em commits, Pull Requests, documentações ou descrições/comentários do Jira.

### 8.4 - No emulador

Criar `functions/.secret.local` (já ignorado pelo git e pelo deploy via `*.local`):

```text
FOOTBALL_DATA_TOKEN=<token>
```

Diferente da produção, o emulador entrega os valores de `.secret.local` a todas as funções, mesmo às que não declaram o segredo. Não use isso como prova de isolamento.

## 9 - Ambiente: Node 22 e Firebase CLI

As Functions rodam em Node 22 (`engines.node` em `functions/package.json`; `functions/.nvmrc`). O `firebase-admin` 14 exige Node 22 ou superior, e o Firebase CLI analisa o código com o próprio Node antes de emular ou implantar. Por isso:

- **Não use o binário standalone** do Firebase CLI (`/usr/local/bin/firebase`) para Functions: ele traz um Node 20 embutido e falha com `ERR_REQUIRE_ESM` (`jose`), deixando o emulador sem funções e impedindo o deploy.
- Use o **Firebase CLI 15.32.1 pelo npm** (`npx firebase-tools@15.32.1`), rodando sobre um **Node 22 isolado**, sem trocar o Node do sistema.

### 9.1 - Instalar o Node 22 isolado (uma vez)

Com `nvm` ou `fnm`, basta `nvm use` / `fnm use` dentro de `functions/` (lê o `.nvmrc`). Sem gerenciador de versões, usar o tarball oficial numa pasta do usuário (validado com a 22.23.4):

```bash
V=v22.23.4
mkdir -p ~/.local/opt /tmp/node22 && cd /tmp/node22
curl -fO https://nodejs.org/dist/$V/node-$V-linux-x64.tar.xz
curl -fO https://nodejs.org/dist/$V/SHASUMS256.txt
grep " node-$V-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c -   # deve imprimir OK/SUCESSO
tar -xJf node-$V-linux-x64.tar.xz -C ~/.local/opt
```

Opcional: conferir também a assinatura de `SHASUMS256.txt` (`SHASUMS256.txt.sig`) com as chaves de [nodejs/release-keys](https://github.com/nodejs/release-keys).

Nada é instalado com `sudo` e o `/usr/bin/node` continua o mesmo. Para remover: `rm -rf ~/.local/opt/node-v22.23.4-linux-x64`.

### 9.2 - Usar no terminal

O PATH muda **só no terminal atual**:

```bash
export PATH="$HOME/.local/opt/node-v22.23.4-linux-x64/bin:$PATH"
node -v                                # v22.23.4
npx firebase-tools@15.32.1 --version   # 15.32.1
```

Para os emuladores, acrescentar o JDK 21: `export JAVA_HOME=/usr/lib/jvm/java-21-openjdk PATH="$JAVA_HOME/bin:$PATH"`.

### 9.3 - Comandos

Na raiz do repositório, com o Node 22 no PATH:

```bash
(cd functions && npm ci && npm test)   # build + testes unitários

# Backend no Firestore Emulator + Security Rules (padrões entre aspas: o Node 22 não aceita pasta em --test)
npx firebase-tools@15.32.1 emulators:exec --only firestore --project demo-betfriends \
  "node --test --test-concurrency=1 'functions/lib/test/**/*.test.js' 'tests/firestore-rules/*.test.mjs'"

# Emuladores de Auth + Firestore + Functions (deve mostrar "Using node@22 from host")
npx firebase-tools@15.32.1 emulators:start --only auth,firestore,functions --project demo-betfriends

# Deploy (seção 7): sempre com --project e --only
npx firebase-tools@15.32.1 deploy --only functions --project betfriends-unirv-2026
```

Para testes locais, use sempre um projeto `demo-*`: o emulador não acessa o Firebase real e os testes recusam rodar fora dele.

## 10 - Sincronização periódica de partidas e liquidação (KAN-50, KAN-86)

`syncMatches` é uma função agendada (Cloud Scheduler) que chama `executarSincronizacao` para o Brasileirão (`BSA`). Cada execução faz **uma** chamada à Football-Data e grava em `matches` só o que mudou. Em geral consulta a janela em volta do horário da execução; a cada `PARTIDAS_SYNC_TEMPORADA_HORAS`, consulta a temporada inteira, para alcançar partidas que saíram da janela (adiamento longo, resultado tardio). A varredura usa o mesmo agendamento, sem função nem job adicional. No desenho previsto, o app só lê `matches`; hoje ele ainda chama o provedor diretamente, até a migração (KAN-42).

Logo depois, na mesma execução, `processarResultados` (KAN-86, `functions/src/desafios/processamentoDeResultados.ts`) usa só o que já está em `matches`: passa para `WAITING_RESULT` os desafios cuja partida saiu de campo, identifica os aptos (partida `FINALIZADA` com resultado) e finaliza cada um com a liquidação idempotente, uma transação por desafio. A falha de um desafio não trava os outros nem deixa efeito parcial; vai para o log (`Desafios aptos que não puderam ser liquidados`) e a próxima execução tenta de novo, sem pagar duas vezes o que já foi finalizado.

| Variável | Padrão | Uso |
|---|---|---|
| `PARTIDAS_SYNC_AGENDA` | `every 5 minutes` | Frequência, em sintaxe cron ou App Engine. Fuso: `America/Sao_Paulo` |
| `PARTIDAS_SYNC_DIAS_ANTES` | `3` | Dias antes de agora (placar e resultado das partidas recentes). Inteiro de 0 a 60 |
| `PARTIDAS_SYNC_DIAS_DEPOIS` | `14` | Dias depois de agora (partidas futuras). Inteiro de 0 a 60 |
| `PARTIDAS_SYNC_TEMPORADA_HORAS` | `6` | Intervalo mínimo entre as consultas à temporada inteira. Inteiro de 1 a 168 |

- **Alternância depois de falha da temporada:** uma falha da temporada não pode impedir a sincronização da janela. Se a última execução consultou a temporada e ela falhou, a seguinte consulta a janela; depois, a temporada é tentada de novo, até concluir. Durante falha persistente, com a agenda padrão, a janela roda aproximadamente a cada 10 minutos, em vez de 5. A temporada só conta como concluída em sucesso (`lastSeasonSuccessAt`), e o sucesso da janela não apaga o histórico de falhas dela (`consecutiveSeasonFailures`). O contrato de `system/matchSync` continua sujeito à decisão E-1 e à revisão de Matheus (`docs/firestore-schema.md` §3.7).
- **Limite do plano Free (10 chamadas/min):** uma chamada por execução, inclusive na varredura da temporada e durante a alternância. Agendas mais frequentes continuam abaixo desse limite, mas aumentam as leituras no Firestore (uma por partida consultada, por execução). Partida sem mudança não é regravada.
- **Ajustar sem mudar código** (por exemplo, depois da medição de atraso da KAN-53): definir as variáveis em `functions/.env.betfriends-unirv-2026` (não é segredo; o Firebase CLI lê o arquivo no deploy) e refazer o deploy. Valor inválido faz o deploy falhar, em vez de publicar uma agenda errada.
- **Falhas:** `matches` mantém o último dado, o processamento de resultados roda com o que já estava sincronizado (mesmo quando a execução termina com erro) e a próxima execução tenta de novo (`retryCount: 0`, uma instância por vez). Toda falha registra `Falha ao buscar partidas no provedor de futebol` e atualiza `system/matchSync` (`docs/firestore-schema.md` §3.7). O token nunca entra em log nem no documento.

| `falha` | Execução | `logger.error` (`evento: sincronizacao-falhou`) |
|---|---|---|
| `credencial`, `resposta-invalida` | Termina com erro | Sempre (`tipo: permanente`) |
| `indisponivel`, `limite-de-requisicoes` | Termina sem erro | A partir da 3ª falha seguida de execuções ou da 3ª seguida da temporada (`tipo: persistente`) |

- **Execuções sobrepostas ou respostas atrasadas:** o ID determinístico evita duplicar, e versão com `providerLastUpdated` mais antigo é ignorada. A primeira confirmação do vencedor é aceita com marca igual ou ausente; resultado já confirmado só muda com marca estritamente mais nova. Essa correção aparece no log (`Provedor corrigiu partidas já finalizadas`) e não altera desafios já liquidados nem BetCoins. Se o resultado corrigido divergir de um desafio já liquidado, há `logger.error` (`evento: divergencia-pos-liquidacao`) e contagem em `system/matchSync`, sem estorno automático.
- **Pendência antes de liquidar em produção (B-4):** o resultado pago vem de `score.winner`, sem conferência com o placar.
- **Parâmetros provisórios:** 6 horas entre varreduras e 240 segundos de limite permanecem inalterados, mas ainda não foram medidos no provedor nem na nuvem. A validação foi feita com emuladores e `fetch` falso, não com infraestrutura real. Se `lastUpdated` mudar sem mudança real, a redução de gravações será menor.
- **Requisitos para rodar em produção:** plano Blaze, `FOOTBALL_DATA_TOKEN` configurado (seção 8.2) e deploy das Functions (seção 7).
- **Alcance atual da liquidação:** nada em produção cria ou inicia desafios ainda (KAN-66 e Callables de desafio pendentes); o processamento só encontra desafios em testes.
- **No emulador:** sem o emulador de Pub/Sub, o Functions Emulator só carrega a definição e não dispara a agenda.
