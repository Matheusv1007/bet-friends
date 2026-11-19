# Achados da Auditoria

Convenção: **Status** começa como `Aberto`; ao corrigir, trocar para `Corrigido (PR #N)`.

---

## A-01 — Fundos reservados podem ficar presos

- **Severidade:** Alta
- **Status:** Aberto
- **Onde:** `functions/src/desafios/` (`maquinaDeEstados.ts`, `aguardarResultado.ts`, `iniciarDesafios.ts`, `aptosParaLiquidacao.ts`, `processamentoDeResultados.ts`)

### O que foi encontrado

A máquina de estados permite `REJECTED` e `CANCELLED`, mas nenhum código emite os eventos `REJEITAR` ou `CANCELAR`. Eles só aparecem em `maquinaDeEstados.ts` e `challenge.ts`. Os comentários citam a KAN-68 (`aguardarResultado.ts:25`, `maquinaDeEstados.ts:38`), mas o cancelamento não foi implementado.

Consequências:

1. **Partida `ADIADA` ou `CANCELADA`:** desafios `ACCEPTED` ou `IN_PROGRESS` não são movidos. `LEVA_A_AGUARDAR_RESULTADO` marca esses status como `false`. A reserva dos dois lados nunca é liberada.
2. **`ACCEPTED` só vira `IN_PROGRESS` se o sync vir a partida em `EM_ANDAMENTO`.** Se o sync (a cada 5 min) não observar esse estado, o desafio fica em `ACCEPTED`. `identificarDesafiosAptos` só considera `WAITING_RESULT`.
3. **Não há callable de recusa** (desafiado) **nem de cancelamento** (criador, enquanto `PENDING`). O criador só recupera a reserva quando o desafio expira no corte de 5 minutos.
4. Partida `SUSPENSA` ou `REVISAO_NECESSARIA` mantém o desafio em `WAITING_RESULT` indefinidamente, apenas com log (KAN-87). Isso é decisão documentada, mas sem prazo de saída.

### Risco

Saldo reservado permanentemente para o usuário. Isso também bloqueia o bônus de recuperação, que exige `saldoReservado == 0` (RN-BET-009).

### Correção proposta

- Callables `rejectChallenge` (desafiado) e `cancelChallenge` (criador, só em `PENDING`), ambas com liberação da reserva no ledger.
- Passo no `processarResultados` que cancela por motivo sistêmico os desafios cuja partida está `ADIADA` ou `CANCELADA`, liberando as reservas.
- Tratar `ACCEPTED` com partida já `FINALIZADA` (passar por `IN_PROGRESS` ou aceitar a transição direta).
- Testes de unidade e de emulador para cada caminho.

---

## A-02 — `getMatchesRest` público e sem proteção

- **Severidade:** Alta
- **Status:** Aberto
- **Onde:** `functions/src/partidas/getMatchesRest.ts:12`, `lib/services/api/partidas_rest_service.dart`, `lib/tela_academica/`

### O que foi encontrado

`onRequest({ cors: true })` sem autenticação, sem App Check e sem limite de uso. Cada chamada lê até 50 documentos de `matches`. O `maxInstances: 10` global limita só a concorrência, não o volume. O `catch` interno devolve valores padrão (`"Mandante"`, `"BSA"`, `2026`) quando um documento está corrompido, escondendo dado inválido.

### Risco

Custo de leitura do Firestore por abuso. Dado corrompido mascarado como válido.

### Correção proposta

- Exigir App Check ou ID token, ou remover o endpoint do deploy depois da entrega acadêmica.
- Restringir `cors` aos origens necessários.
- Remover o fallback silencioso; registrar em log e omitir o documento inválido.

---

## A-03 — Índices compostos ausentes

- **Severidade:** Alta
- **Status:** Aberto
- **Onde:** `firestore.indexes.json`, `functions/src/partidas/getMatchesRest.ts`, `lib/data/firestore/partidas_repository.dart:32`, `lib/data/firestore/challenge_repository.dart:260`

### O que foi encontrado

`firestore.indexes.json` só define índices de `challenges`. Faltam:

| Coleção | Consulta | Campos |
|---|---|---|
| `matches` | `where competitionCode ==` + `orderBy startsAtUtc` | `competitionCode ASC`, `startsAtUtc ASC` |
| `friendships` | `where participants array-contains` + `where status ==` | `participants CONTAINS`, `status ASC` |

O cliente esconde a falta do índice de `matches` com `catch (_)` e uma consulta sem filtro (`partidas_repository.dart:36`). `getMatchesRest` não tem fallback.

### Risco

`getMatchesRest` devolve 500 em produção e o app usa um caminho degradado. **[INFERÊNCIA]**: não foi confirmado contra o projeto real; os índices podem existir apenas por criação manual no console, o que quebra a reprodutibilidade do ambiente.

### Correção proposta

- Adicionar os índices em `firestore.indexes.json` e conferir com `firebase deploy --only firestore:indexes --dry-run` ou contra o emulador.
- Levantar todas as consultas do cliente e do backend e conferir uma a uma contra o arquivo.
- Remover o fallback do cliente depois que o índice estiver garantido.

---

## A-04 — Release Android assinado com chave de debug

- **Severidade:** Média
- **Status:** Aberto
- **Onde:** `android/app/build.gradle.kts:37-39`

### O que foi encontrado

`signingConfig = signingConfigs.getByName("debug")` com `TODO`. Também há `TODO` sobre o `applicationId` (linha 21), que já está definido como `com.unirv.betfriends`. Versão em `1.0.0+1`.

### Risco

APK/AAB de release não publicável e assinado com chave pública conhecida.

### Correção proposta

- Ler `key.properties` (já ignorado no `.gitignore`) e criar `signingConfigs.release`, com fallback para debug apenas quando o arquivo não existir.
- Documentar a geração do keystore e que ele nunca vai para o git.
- Remover os `TODO` obsoletos.

---

## A-05 — Sem App Check; `searchUsers` permite varredura

- **Severidade:** Média
- **Status:** Aberto
- **Onde:** `functions/src/core/callable.ts`, `functions/src/perfil/searchUsers.ts`

### O que foi encontrado

Nenhuma callable usa `enforceAppCheck`. `searchUsers` faz busca por prefixo em `users` e devolve até 50 registros. Qualquer conta autenticada pode enumerar todos os usuários com prefixos curtos. Não há limite de chamadas por usuário. Prefixo de 1 caractere é aceito.

### Risco

Enumeração de usuários e uso abusivo das funções por clientes não oficiais.

### Correção proposta

- Habilitar App Check no app e `enforceAppCheck: true` em `authedCallable` (opção configurável para o emulador).
- Exigir mínimo de 2 ou 3 caracteres na busca.
- Avaliar limite de taxa por UID.

---

## A-06 — `syncMatches` varre desafios em série

- **Severidade:** Média
- **Status:** Aberto
- **Onde:** `functions/src/partidas/syncMatches.ts:33-34`, `functions/src/desafios/expirarDesafios.ts`, `iniciarDesafios.ts`, `aguardarResultado.ts`

### O que foi encontrado

A cada 5 minutos, com `timeoutSeconds: 240` e `maxInstances: 1`, o job lê todos os desafios `PENDING`, `ACCEPTED`, `IN_PROGRESS` e `WAITING_RESULT` e abre uma transação por desafio, em série. Cada passo relê a partida.

### Risco

Com mais desafios, o job estoura o timeout, o processamento de resultados atrasa e a liquidação também.

### Correção proposta

- Agrupar por `matchId` e ler cada partida uma vez.
- Filtrar por partidas que mudaram de estado, em vez de varrer tudo.
- Limitar concorrência (por exemplo, lotes paralelos pequenos) e registrar duração por etapa.

---

## A-07 — `catch (_)` genéricos no cliente

- **Severidade:** Média
- **Status:** Aberto
- **Onde:** `lib/app.dart:47`, `lib/data/firestore/challenge_repository.dart`, `friendship_repository.dart`, `partidas_repository.dart`, `user_profile_repository.dart`, `user_search_repository.dart`, `lib/models/friendship_model.dart`, `lib/provider/auth_provider.dart`, `lib/services/api/partidas_rest_service.dart`, `lib/tela_amigos/tela_buscar_usuarios.dart`

### O que foi encontrado

Mais de 20 blocos `catch (_)`. Em `app.dart:47`, falha ao criar `ChallengeService` vira `null` em silêncio.

### Risco

Falhas reais (permissão, índice, rede, dado inválido) viram comportamento degradado sem registro, o que dificulta o diagnóstico.

### Correção proposta

- Tratar cada caso: capturar tipos específicos (`FirebaseException`, `FormatException`), registrar com `debugPrint`/log e propagar erro de domínio.
- Remover o `try/catch` de `app.dart` e injetar o serviço corretamente.

---

## A-08 — Artefatos versionados e chave de API

- **Severidade:** Baixa
- **Status:** Corrigido no código (branch `chore/A-08-A-13-higiene-repo`): relatório removido do git e `/android/build/` ignorado; restrição da chave documentada no `README.md`. Falta aplicar a restrição no Google Cloud Console (ação manual).
- **Onde:** `android/build/reports/problems/problems-report.html`, `android/app/google-services.json`

### O que foi encontrado

- O relatório de build do Gradle está no git.
- `google-services.json` contém a chave `AIza…` do projeto. Esse tipo de chave não é segredo do servidor, mas deve ter restrição de uso.

### Correção proposta

- `git rm --cached` no relatório e ignorar `android/build/` no `.gitignore`.
- Restringir a chave no Google Cloud Console (pacote `com.unirv.betfriends` + SHA-1) e registrar a decisão na documentação.

---

## A-09 — Aliases de payload e tabela de erros duplicada

- **Severidade:** Baixa
- **Status:** Aberto
- **Onde:** `functions/src/desafios/createChallenge.ts`, `functions/src/desafios/acceptChallenge.ts`

### O que foi encontrado

- `createChallenge` aceita `challengedId`/`friendId`/`desafiadoId` e `challengerPrediction`/`prediction`/`palpite`. `acceptChallenge` aceita `challengedPrediction`/`prediction`/`palpite`. O app usa um só nome.
- A tabela `CODIGO_HTTPS` e o bloco de tradução de erros estão copiados nos dois arquivos.

### Correção proposta

- Manter só os nomes que o app usa (confirmar em `lib/data/firestore/challenge_repository.dart`) e atualizar `docs/callable-functions.md`.
- Extrair a tradução de erros de desafio para um módulo compartilhado.

---

## A-10 — Código morto ou legado no app

- **Severidade:** Baixa
- **Status:** Aberto
- **Onde:** `lib/services/api/api_client.dart`, `lib/services/api/partidas_service.dart`, `lib/app.dart`

### O que foi encontrado

- `ApiClient` não é instanciado em produção, apenas definido. O fluxo `_getPartidasFromClient` do `PartidasService` (consulta direta à Football-Data, KAN-105) só roda com cliente injetado em teste.
- Parâmetro `apiKey` marcado como `@Deprecated`.
- `app.dart` tem um bloco grande de `App` comentado e comentários com nomes de pessoas.

### Correção proposta

Confirmar com o grupo se algum teste ou a entrega acadêmica depende do `ApiClient`. Se não, remover o fluxo direto, o `apiKey` e os comentários, migrando os testes que o usam.

---

## A-11 — Arquivos grandes e nomes fora do padrão

- **Severidade:** Baixa
- **Status:** Aberto
- **Onde:** `lib/telas_principais/homePage.dart` (918 linhas), `lib/tela_criar_desafio/tela_criar_desafio.dart` (911), `lib/widgets_homePage/cardDeDesafiosAtivos.dart` (668), `lib/tela_perfil/tela_perfil.dart` (720)

### O que foi encontrado

Seis arquivos violam `file_names` (único aviso do `flutter analyze`): `homePage.dart`, `appbarDasPartidas.dart`, `cardDeCarteira.dart`, `cardDeDesafio.dart`, `cardDeDesafiosAtivos.dart`, `cardDePartidas.dart`. Telas e widgets grandes misturam layout, estado e formatação.

### Correção proposta

- Renomear para `snake_case` com `git mv` e atualizar imports, em um commit isolado.
- Extrair widgets menores dos arquivos acima, sem mudar comportamento.

---

## A-12 — Sem CI

- **Severidade:** Baixa
- **Status:** Aberto
- **Onde:** raiz do repositório (não existe `.github/`)

### O que foi encontrado

Nada executa `flutter analyze`, `flutter test` ou `npm test` automaticamente nos pull requests. Os testes de regras e de emulador dependem de execução manual.

### Correção proposta

Workflow no GitHub Actions com `flutter analyze`, `flutter test` e, em `functions/`, `npm ci` + `npm test`. Testes de emulador em job separado.

---

## A-13 — Documentos soltos

- **Severidade:** Baixa
- **Status:** Sem alteração no repositório. Os arquivos são ignorados pelo git e pertencem ao responsável; apagar ou mover `AnaliseTemporaria.md` fica a critério dele.
- **Onde:** `AnaliseTemporaria.md` (ignorado pelo git, 768 KB), `firestore-debug.log` (ignorado)

### O que foi encontrado

Arquivos de trabalho na raiz do projeto. Não estão versionados, mas poluem o diretório e podem ser commitados por engano se o `.gitignore` mudar.

### Correção proposta

Mover o conteúdo útil para `docs/` ou apagar. Nenhuma alteração no git é necessária.

---

## Observação — README desatualizado sobre o token da football-data.org

Durante a correção do A-08 verificou-se que o aviso do `README.md` dizia que o token estava no código do app. Isso não é mais verdade: o token foi removido do código no commit `34fd242` e o app lê `matches` do Firestore. O valor antigo permanece no histórico do git (commit `8462ffe`) e `docs/callable-functions.md` §8.3 (KAN-102) registra a credencial como revogada. O aviso do README foi corrigido. A revogação no painel do provedor não pode ser confirmada a partir do repositório; vale conferir manualmente que o token antigo foi de fato invalidado. O README ainda lista "troca do token" e "app lendo `matches`" em "Pendente para o MVP"; revisar essa seção.
