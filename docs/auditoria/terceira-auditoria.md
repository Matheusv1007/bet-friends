# Terceira Auditoria Técnica

| Campo | Valor |
|---|---|
| Data | 2026-11-19 |
| Base | branch `qas`, commit `31a1fe0` (inclui as ondas de correção da segunda auditoria, PRs #92 a #95) |
| Escopo | Regressões e correções incompletas das ondas de backend, app e infra/docs; segurança e lógica do backend; app Flutter; CI, dependências e documentação |
| Método | Quatro revisões independentes e somente leitura (segurança do backend, lógica do backend, app, repositório/CI/docs), com os achados confirmados por leitura do código e execução local dos testes. Nada foi publicado e nada foi lido ou gravado no Firebase de produção pelos revisores. Leitura de produção feita apenas pelo responsável pela auditoria: lista de Functions, logs do `syncMatches` e quantidade de índices |
| Relação com as auditorias anteriores | Os achados A-01 a A-13 ([achados.md](achados.md)) e N-01 a N-30 ([segunda-auditoria.md](segunda-auditoria.md)) foram tratados. Aqui entram só problemas novos e correções que ficaram incompletas (marcadas com **[corrige o N-xx]**) |

## Linha de base

| Verificação | Resultado |
|---|---|
| `flutter analyze` | zero avisos |
| `flutter test` | 349 passaram |
| `npm test` (`functions/`) | 210 passaram |
| Backend e Security Rules no emulador (JDK 21, sob `flock`) | 548 de 548 |
| `integration_test/` | não executado (não há aparelho Android disponível; fora do CI) |
| `npm audit --omit=dev` | 7 moderadas, as mesmas já conhecidas (N-25) |
| `npm audit` completo | 18 (13 moderadas, 5 altas), todas na cadeia de desenvolvimento do `firebase-tools` |
| Actions do CI por SHA | os 5 SHAs conferem com as tags indicadas nos comentários (`git ls-remote`) |
| Produção (somente leitura) | 14 Functions publicadas em `southamerica-east1`; `syncMatches` rodando a cada 5 minutos, sem erros recentes, 39 partidas da `BSA` na janela; 12 índices compostos declarados no projeto (o estado "Ativo" não foi lido) |

**Nenhum achado gera ou destrói BetCoins e nenhum é de severidade Alta.** Ledger, reservas e liquidação continuam atômicos, com leituras antes das gravações em todos os caminhos novos. Os pontos de atenção são o cancelamento por tempo do N-05 (T-01), dois itens do app que o N-06 e o N-07 deixaram incompletos (T-03 e T-05) e a paginação de solicitações de amizade que o app não usa (T-02).

## Resumo dos achados

| ID | Severidade | Título | Área |
|---|---|---|---|
| T-01 | Média | As saídas por tempo do N-05 cancelam com base em dados que podem estar velhos **[corrige o N-05]** | Backend |
| T-02 | Média | O app ignora a paginação de solicitações de amizade; acima de 100 pendências, parte fica invisível **[corrige o N-11]** | Backend/App |
| T-03 | Média | A atualização automática de partidas acontece a cada 10 minutos e não busca ao voltar à tela **[corrige o N-07]** | App |
| T-04 | Média | Listeners de desafios continuam abertos após "Tentar novamente" **[corrige o N-19]** | App |
| T-05 | Média | Nomes dos adversários vêm de `getFriends` carregado uma vez; ex-amigos viram "Amigo" **[corrige o N-06]** | App |
| T-06 | Média | `npm run serve` sobe sem o emulador do Firestore e com o projeto de produção selecionado | Processo/Docs |
| T-07 | Baixa | Varredura com falhas de gravação é registrada como sucesso **[corrige o N-16]** | Backend |
| T-08 | Baixa | O alerta de `IN_PROGRESS` acima de 24 h se repete a cada execução e não cobre todos os casos **[corrige o N-05]** | Backend |
| T-09 | Baixa | O `finally` do `syncMatches` pode mascarar o erro original **[corrige o N-16]** | Backend |
| T-10 | Baixa | A recusa do N-04 não chega ao app: a partida remarcada aparece como apostável **[corrige o N-04]** | App/Backend |
| T-11 | Baixa | Uma consulta que falha derruba a seção inteira (partidas e desafios) | App |
| T-12 | Baixa | Descrição da partida fica "indisponível" para sempre se a busca falhar **[corrige o N-06]** | App |
| T-13 | Baixa | Falha na limpeza do logout passa em silêncio **[corrige o N-22]** | App |
| T-14 | Baixa | `allowBackup="false"` não bloqueia a transferência entre aparelhos **[corrige o N-22]** | Android |
| T-15 | Baixa | Criar Desafio mostra duas mensagens contraditórias quando falha o carregamento de amigos **[corrige o N-20]** | App |
| T-16 | Baixa | A fixação do `firebase-tools` como devDependency trouxe 18 advisories de desenvolvimento **[corrige o N-26]** | Deps |
| T-17 | Baixa | Documentação ainda diverge do código **[corrige o N-13]** | Docs |
| T-18 | Baixa | Lacunas de teste nas correções novas **[corrige o N-08]** | Testes |

---

## T-01 — Saídas por tempo do N-05 cancelam com dados velhos (Média) [corrige o N-05]

- **Onde:** `functions/src/desafios/cancelamento.ts:171-174`; `functions/src/partidas/syncMatches.ts:39-42`.
- **Evidência:** `ACCEPTED` com partida `AGENDADA` cancela quando `agora - startsAtUtc > 7 dias`; `WAITING_RESULT` com partida `SUSPENSA`/`REVISAO_NECESSARIA` cancela quando `agora - updatedAt > 7 dias`. Nenhuma das duas confere se o provedor atualizou a partida nesse período. Com o N-16, `processarResultados` agora roda também depois de falha permanente de credencial (`ErroDaSincronizacao`).
- **Risco:** se a sincronização ficar 7 dias ou mais parada (token revogado, provedor fora do ar), desafios de jogos que aconteceram viram `CANCELLED/MATCH_POSTPONED` com reembolso. Quando o sync volta, a partida chega `FINALIZADA`, mas o desafio já é terminal e o resultado se perde. Antes da correção, o desafio só esperava e era liquidado depois. Não há perda de saldo, mas a aposta é anulada sem volta. A frequência é inferência.
- **Correção:** aplicar as duas regras só quando houve sincronização recente de verdade (por exemplo, `system/matchSync.lastSeasonSuccessAt` posterior ao limite), ou gravar na partida o instante em que foi vista pela última vez. Teste novo: com sincronização parada, nada é cancelado.
- **Confiança:** Alta no caminho de código.

## T-02 — O app ignora a paginação de solicitações de amizade (Média) [corrige o N-11]

- **Onde:** `functions/src/amigos/friendshipFirestore.ts:333-342`; `functions/src/amigos/getFriendRequests.ts:27-29`; `lib/data/firestore/friendship_repository.dart:242-250`; `lib/tela_amigos/tela_comunicacoes_amizade.dart:44-58`.
- **Evidência:** a callable devolve até 100 solicitações ordenadas por `requesterId` e um `nextCursor`. O app chama sem cursor, guarda só `requests` e mostra a lista como completa. Não há teto de pendências recebidas; as cotas são por remetente e por par.
- **Risco:** com 101 ou mais pendências, as de UIDs "altos" ficam invisíveis até as anteriores serem resolvidas. Várias contas ainda conseguem encher a caixa de uma vítima, que era o objetivo do N-11. A inferência da obstrução não foi reproduzida.
- **Correção:** propagar o cursor até a tela com "carregar mais", ordenar por `createdAt` (índice novo) e avaliar um teto de pendências recebidas sem permitir que esgotar a cota da vítima bloqueie pedidos legítimos.
- **Confiança:** Alta (leitura de código).

## T-03 — Polling a cada 10 minutos e sem busca ao voltar (Média) [corrige o N-07]

- **Onde:** `lib/telas_principais/home_page.dart:30,105,114`; `lib/provider/partidas_provider.dart:29,88,127`.
- **Evidência:** intervalo do timer e validade do cache são os dois 5 min. O timer nasce no `initState`, mas `_ultimoFetchSucesso` só é gravado depois do primeiro frame mais a rede; no primeiro disparo o cache ainda vale e a consulta é pulada. Só o disparo seguinte busca. Ao voltar do segundo plano (`_iniciarPolling()`) e ao voltar de outra tela, nada é buscado.
- **Risco:** placar e status chegam a cerca de 10 min velhos; quem alterna de app com frequência pode nunca receber atualização. Efeito real é inferência.
- **Correção:** cache um pouco menor que o intervalo (ex.: intervalo menos 30 s) ou `forcar` no polling; buscar (respeitando o cache) em `resumed` e ao voltar para a Home. Teste com relógio injetado.
- **Confiança:** Alta no cálculo.

## T-04 — Listeners de desafios abertos após "Tentar novamente" (Média) [corrige o N-19]

- **Onde:** `lib/telas_principais/home_page.dart:125,298`; `lib/services/combinar_desafios.dart:29`.
- **Evidência:** a Home envolve o stream com `asBroadcastStream()` sem `onCancel`; a assinatura de origem continua viva sem ouvintes e o `onCancel` de `combinarDesafios`, que cancelaria as duas consultas, nunca roda em produção.
- **Risco:** com só uma consulta falhando, cada "Tentar novamente" deixa a outra viva e soma outro listener, com mais leituras. O teste do N-19 não pega isso porque escuta o repositório direto.
- **Correção:** `StreamController.broadcast(onListen, onCancel)` em `combinarDesafios`, sem o `asBroadcastStream`, ou guardar a assinatura e cancelá-la no `dispose` e no retry. Teste passando pela Home.
- **Confiança:** Alta.

## T-05 — Nomes só de `getFriends`, carregado uma vez (Média) [corrige o N-06]

- **Onde:** `lib/widgets_home_page/card_de_desafios_ativos.dart:60,228`; `apresentacao_desafios.dart:22`.
- **Evidência:** `_carregarNomes()` roda só no `initState` e qualquer UID fora da lista vira "Amigo". A Home continua montada sob as outras telas, então a lista nunca recarrega.
- **Risco:** desafios com ex-amigos (inclusive os cancelados por `FRIENDSHIP_REMOVED`) e os finalizados antigos mostram "Amigo"; quem virou amigo depois da abertura da Home aparece como "Desafio de Amigo", e o modal de aceite recebe `nomeCriador: 'Amigo'`. Se `getFriends` falhar, todos viram "Amigo", sem nova tentativa.
- **Correção:** gravar o nome público no desafio na criação (já sugerido no N-06) ou criar consulta pública de nomes por lista de UIDs; recarregar quando aparecer UID desconhecido.
- **Confiança:** Alta.

## T-06 — `npm run serve` pode atingir a produção (Média)

- **Onde:** `functions/package.json:13`; `.firebaserc:3`; `functions/src/core/firebase.ts:4-9`; `docs/callable-functions.md:79-89`.
- **Evidência:** o script faz `firebase emulators:start --only auth,functions`, sem Firestore e sem `--project`; o `.firebaserc` seleciona o projeto de produção; o Admin SDK inicializa sem exigir emulador. O próprio CLI avisa que, sem o emulador do Firestore, as chamadas afetam a produção.
- **Risco:** com credenciais locais disponíveis, chamadas financeiras e de cadastro feitas "localmente" podem gravar no banco real. Efeito real é inferência (não executado).
- **Correção:** incluir `firestore` e `--project demo-betfriends` no script e documentar a configuração coerente dos três SDKs; opcionalmente falhar na inicialização do Admin quando o projeto não for `demo-*` e o emulador não estiver ativo.
- **Confiança:** Alta no encadeamento.

## T-07 a T-18 (Baixa)

- **T-07 — Varredura com falhas é registrada como sucesso** (`sincronizacao.ts:122`; `execucaoDaSincronizacao.ts:98-99`) **[corrige o N-16]**. Um erro de `gravarMatch` vira `recusadas` e o resultado segue `ok: true`, então `lastSeasonSuccessAt` avança e `consecutiveFailures` zera mesmo com 100% das gravações falhas. Adia a próxima varredura em 6 h, esconde a falha do alerta e agrava o T-01. Correção: não marcar sucesso (ou não avançar `lastSeasonSuccessAt`) quando houver falhas inesperadas e contá-las à parte no `lastSummary`.
- **T-08 — Alerta de `IN_PROGRESS` repetido** (`cancelamento.ts:167-169`) **[corrige o N-05]**. O `logger.error` dispara a cada execução (cerca de 288 por dia por desafio), sem deduplicação, e só vale com a partida `EM_ANDAMENTO`; partida que volta para `AGENDADA` com desafio `IN_PROGRESS` não tem saída nem alerta. Correção: alertar uma vez por desafio e cobrir qualquer partida não terminal após 24 h.
- **T-09 — `finally` mascara o erro original** (`syncMatches.ts:39-42`) **[corrige o N-16]**. Se a sincronização e o `processarResultados` lançarem, só o segundo erro é propagado; o primeiro não é logado. Correção: capturar, logar e relançar depois do processamento.
- **T-10 — O N-04 não chega ao app** (`lib/data/firestore/partidas_repository.dart:35-56`) **[corrige o N-04]**. A lista filtra por `competitionCode` e `startsAtUtc`, sem usar `originalStartsAtUtc`; a partida remarcada além do tolerado aparece apostável e criar ou aceitar sempre recusa com "não está disponível". Correção: filtrar no app com a mesma conta de `remarcadaAlemDoTolerado` ou expor um campo calculado.
- **T-11 — Uma consulta que falha derruba a seção** (`combinar_desafios.dart:26`; `partidas_repository.dart:47`). Erro na consulta de encerrados esconde também os pendentes recebidos; se a consulta `recentes` (índice DESC novo) falhar, o `Future.wait` descarta o resultado da `janela`. Se o app for distribuído antes de os índices novos (`updatedAt DESC`, `startsAtUtc DESC`) ficarem ativos, as seções falham, e o emulador não exige índices, então nenhum teste pega. Correção: tratar o erro de cada consulta separadamente e publicar os índices antes de distribuir o app.
- **T-12 — Descrição da partida indisponível para sempre** (`card_de_desafios_ativos.dart:79,163,229`) **[corrige o N-06]**. O ID entra em `_consultadas` e não sai em caso de erro; o repositório é criado direto, sem injeção (6 "Falha ao carregar descrição" nos testes); o modal permite aceitar sem mostrar a partida. Correção: remover o ID em caso de erro, mostrar "Carregando partida…" e injetar o repositório.
- **T-13 — Limpeza do logout falha em silêncio** (`auth_service.dart:40-44`; `home_page.dart:385-390`) **[corrige o N-22]**. `signOut` roda antes de `terminate()` e `clearPersistence()`, o `AuthGate` desmonta a Home e o `catch` sai em `if (!mounted) return`; se a limpeza falhar, o cache do usuário anterior fica no aparelho sem aviso. A solução também depende de um detalhe interno do plugin Android (recriação do cliente após `terminate()`), contra a documentação. Correção: gravar marca de pendência e limpar na próxima abertura, antes de qualquer acesso ao Firestore. Confiança Média, não testado em Android.
- **T-14 — `allowBackup="false"` não bloqueia transferência entre aparelhos** (`AndroidManifest.xml:4`) **[corrige o N-22]**. Com `targetSdk` 31 ou maior, o atributo desliga o backup na nuvem, mas não a transferência direta. Correção: `android:dataExtractionRules` excluindo `cloud-backup` e `device-transfer`. Confiança Média.
- **T-15 — Mensagens contraditórias em Criar Desafio** (`tela_criar_desafio.dart:439-452`; `seletor_amigo_desafio.dart:48`) **[corrige o N-20]**. Com erro no carregamento de amigos, a lista fica vazia e o seletor mostra "Você ainda não possui amigos aceitos" junto com "Não foi possível carregar os amigos". Correção: esconder o estado vazio quando houver erro.
- **T-16 — Advisories de desenvolvimento do `firebase-tools`** (`functions/package.json:23`; `package-lock.json`) **[corrige o N-26]**. Fixar o CLI como devDependency (para o `npx` do CI) acrescentou `basic-ftp@5.3.1` e outras: 18 vulnerabilidades (13 moderadas, 5 altas) pela cadeia `firebase-tools → proxy-agent → pac-proxy-agent → get-uri → basic-ftp`. Não entram no pacote de deploy (`devDependencies`, `node_modules` ignorado) e `npm audit --omit=dev` segue nas 7 moderadas conhecidas. Correção: atualizar o CLI quando sair versão com a cadeia corrigida, não aplicar o downgrade sugerido pelo `npm audit`, e acompanhar também as dependências de desenvolvimento no Dependabot.
- **T-17 — Documentação ainda diverge do código** **[corrige o N-13]**:
  - `README.md:135,140` diz que o repositório inclui `lib/firebase_options.dart`, removido no N-29; `firebase.json:11-17` ainda tem a entrada que o gera, e `flutterfire configure` o recria sem uso.
  - `docs/callable-functions.md:67-70` exemplifica `createChallenge` só com `matchId` e `amount`; o leitor exige `challengedId` e `challengerPrediction` (`functions/src/desafios/payload.ts:29-35`), então o exemplo responde `invalid-argument`.
  - `docs/firestore-schema.md:463` diz que só `searchUsers` usa `rateLimits`; agora usam também criar e cancelar desafio e enviar e reabrir amizade (chaves por par/remetente, `friendshipFirestore.ts:99-102`).
  - `docs/entrega-2/` (`README.md`, `checklist.md`, `funcionalidades.md`, `status-report.md`) e `roteiro-demonstracao.md:26-27` descrevem o estado de 01/11 (sem amizades, API direta, polling de 30 s, desafio demonstrativo e "sem gravação"); o roteiro manda enviar um desafio dizendo que nada é gravado, mas agora a operação é real. Marcar como histórico ou atualizar.
  - `tests/firestore-rules/README.md:39` ainda diz que a autorização do backend só poderá ser testada "quando as Functions existirem".
  - Comandos de emulador sem o `flock` que o `integration_test/README.md:112` exige: `README.md:118-124`, `docs/callable-functions.md:233-237`, `tests/firestore-rules/README.md:23-25`.
- **T-18 — Lacunas de teste** **[corrige o N-08]**. (a) O N-05 só é testado na função pura: não há teste no emulador de `processarResultados` cancelando `ACCEPTED` velho ou `WAITING_RESULT` + `SUSPENSA` e devolvendo as duas reservas. (b) As cotas são chamadas de atômicas, mas nenhum teste roda chamadas concorrentes. (c) Nenhum teste confere `where`/`orderBy` das consultas contra `firestore.indexes.json` (o emulador não exige índice composto; a conferência manual foi feita nesta auditoria e bate). (d) O teste do N-19 não passa pela Home (T-04). (e) Nenhum teste prova que o polling busca após 5 min (`DateTime.now()` não é injetado). (f) O teste do N-22 só confere a ordem de chamadas em objetos falsos; o caminho real é exercido apenas em `cadastro_emulator_test`, que não roda no CI. (g) Em `flutter test`, "Observar desafios na página inicial" falha 32 vezes (sem Firebase) em testes da Home que não verificam isso. (h) Faltam testes de ex-amigo, de amigo aceito depois da abertura da Home e de falha na busca da partida (T-05, T-12).

---

## O que foi examinado e está correto

1. **Dinheiro:** reservas devolvidas uma única vez, IDs de ledger determinísticos, pot de 2x, cancelamento e liquidação releem desafio e partida na transação (sem liquidação dupla).
2. **Leituras antes de gravações** nas transações novas: criação, cancelamento, envio de amizade e consumo de cota; erro de regra aborta sem consumir cota.
3. **Consulta de candidatos ativos (N-10):** cobre `PENDING` como criador e `ACCEPTED`/`IN_PROGRESS`/`WAITING_RESULT` em qualquer papel; a exceção do convite recebido continua; criações concorrentes do mesmo usuário se serializam pela leitura do saldo.
4. **Cotas:** janela fixa com reinício correto, contador na mesma transação da operação; `resource-exhausted` chega intacto ao app. Elas limitam operações bem-sucedidas, não tentativas; não são proteção geral contra inundação de chamadas.
5. **N-09:** código, mensagem e `details` idênticos para relação inexistente e de terceiros, no aceite e na recusa. O cursor só muda o ponto inicial; filtros ficam presos ao UID autenticado.
6. **N-04 no backend:** criar e aceitar recusam remarcação além do tolerado; partida sem `originalStartsAtUtc` é rejeitada; fronteiras `> 7 d` e `> 24 h` em milissegundos UTC.
7. **Índices:** as 5 consultas novas do app e as 3 do backend têm índice composto correspondente; a tabela do schema bate com o arquivo (12).
8. **Security Rules:** saldo, ledger, amizades, partidas e desafios continuam sem escrita pelo cliente; perfil só admite `displayName` e `updatedAt`.
9. **CI e segredos:** `contents: read`, `persist-credentials: false`, 5 actions fixadas por SHA que conferem com a tag; `.env.betfriends-unirv-2026` só com configuração pública; token no Secret Manager; sincronização em produção funcionando.
10. **App:** saldo nunca é inventado; nenhuma partida é escolhida automaticamente; travas e `PopScope` contra duplo envio; busca com contador; handlers globais de erro; nada importa os arquivos removidos no N-29.

## Ordem de correção proposta

1. **Onda 1 (backend, antes de ter muitos desafios reais):** T-01, T-07, T-09, T-08, com o teste de emulador que falta (T-18a, T-18b) e o T-06.
2. **Onda 2 (app):** T-03, T-04, T-05, T-02 (com ajuste da callable: ordenar por `createdAt`), T-10, T-11, T-12, T-15, T-13, T-14. Publicar índices antes de distribuir o app.
3. **Onda 3 (docs e dependências):** T-17, T-16 e os testes restantes do T-18.

## Pendências que dependem da equipe
- Confirmar a regra "SUSPENSA/REVISAO_NECESSARIA por mais de 7 dias cancela com reembolso" (decisão do responsável pela correção, aplicada na segunda onda).
- T-05: gravar o nome público no desafio na criação (muda o modelo e o backend) ou consultar nomes por UID (nova callable).
- Itens manuais já listados nas auditorias anteriores: keystore e `key.properties`, restrição da chave de API, confirmar a revogação do token antigo (N-30), proteção de branch (adiada), App Check em produção, N-14 (Play).
