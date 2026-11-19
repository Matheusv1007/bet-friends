# Segunda Auditoria Técnica

| Campo | Valor |
|---|---|
| Data | 2026-11-19 |
| Base | branch `qas`, commit `34ac4f5` (inclui a KAN-107, jornada completa do MVP) |
| Escopo | Backend e Security Rules (segurança e lógica), app Flutter, repositório, CI, documentação e qualidade dos testes |
| Método | Quatro revisões independentes e somente leitura (segurança do backend, lógica do backend, app, repositório e processo), com os achados confirmados por leitura do código, reprodução local ou execução de testes. Nada foi publicado nem tocou o Firebase real |
| Relação com a primeira auditoria | Os achados A-01 a A-13 ([achados.md](achados.md)) foram corrigidos. Aqui entram só problemas novos e correções que ficaram incompletas (marcadas com **[corrige o A-xx]**) |

## Linha de base

| Verificação | Resultado |
|---|---|
| `flutter analyze` | zero avisos |
| `flutter test` | 339 passaram |
| `npm test` (`functions/`) | 207 passaram |
| Backend e Security Rules no emulador (última execução, antes da KAN-107) | 538 de 538 |
| Execução do CI em 19/11 | 4 de 4 verdes |
| `npm audit --omit=dev` | 7 vulnerabilidades transitivas (1 baixa, 6 moderadas) |

O dinheiro virtual está protegido: o ledger é atômico, cada lançamento tem ID determinístico (sem pagamento duplo), o pot é sempre 2x o valor sem taxa, e leituras vêm antes das gravações em todos os caminhos financeiros. **Nenhum achado gera ou destrói BetCoins.** Os problemas graves estão em outro lugar: o app não consegue criar desafios com dados reais, o ciclo de vida do desafio quando a partida muda, e o CI que vai quebrar sozinho amanhã.

## Resumo dos achados

| ID | Severidade | Título | Área |
|---|---|---|---|
| N-01 | Alta | A lista de partidas traz só as 30 primeiras da temporada: nenhuma partida futura aparece | App |
| N-02 | Alta | Criar Desafio pela Home não carrega amigos nem saldo (lê `users/{amigo}`, negado pelas regras) | App |
| N-03 | Alta | Testes de emulador com data fixa quebram o CI a partir de 20/11 às 19:55 UTC | CI/testes |
| N-04 | Alta | Prazo de adiamento conta da primeira sincronização: desafio criado depois de uma remarcação é cancelado sozinho **[corrige o A-01]** | Backend |
| N-05 | Média | Desafio `ACCEPTED`/`IN_PROGRESS` fica preso se a partida guardada deixa de mudar de status | Backend |
| N-06 | Média | Interface mostra UIDs e IDs de partida crus; o aceite (que reserva BetCoins) não mostra a partida | App |
| N-07 | Média | Atualização automática relê 30 partidas por minuto ignorando o cache | App |
| N-08 | Média | Os testes não cobrem os repositórios reais; o relatório da KAN-107 afirma mais do que verifica | Testes/docs |
| N-09 | Média | `acceptFriendRequest`/`rejectFriendRequest` revelam se existe relação entre terceiros | Backend |
| N-10 | Média | Criar e cancelar desafio em ciclo gera documentos e leituras sem limite de uso | Backend |
| N-11 | Média | Caixa de solicitações de amizade cresce sem limite e é lida inteira | Backend |
| N-12 | Média | Configuração de segurança e de agenda fica em arquivo ignorado pelo git | Processo |
| N-13 | Média | Documentação desatualizada: README, `callable-functions.md` §10, `firestore-schema.md` §6 **[corrige o A-03 e o A-08]** | Docs |
| N-14 | Média | Faltam itens de release: política de privacidade, exclusão de conta, licença, changelog, versionamento | Release |
| N-15 | Média | `jornada_mvp_emulator_test.dart` depende da ordem dos arquivos | Testes |
| N-16 | Baixa | Erro do job `syncMatches` num lote de partidas pula o processamento de resultados | Backend |
| N-17 | Baixa | A partida escolhida em Criar Desafio é trocada em silêncio ao atingir o corte | App |
| N-18 | Baixa | Cancelar desafio não trava o botão; o modal de aceite fecha no meio do envio | App |
| N-19 | Baixa | O listener de desafios lê o histórico inteiro, sem limite nem ordem | App |
| N-20 | Baixa | Erro no stream de desafios vira o bloco "demonstrativo" para sempre | App |
| N-21 | Baixa | `registrarErro` pode não chegar a nenhum lugar útil em release **[corrige o A-07]** | App |
| N-22 | Baixa | `allowBackup` ligado; sessão e cache do Firestore ficam no aparelho após o logout | App/Android |
| N-23 | Baixa | Acessibilidade: controles sem semântica, áreas de toque pequenas, contraste | App |
| N-24 | Baixa | Na busca de usuários, uma resposta antiga pode sobrescrever a mais nova | App |
| N-25 | Baixa | Dependências com advisories e SDKs uma major atrás; sem atualização automática | Deps |
| N-26 | Baixa | Workflow com actions sem SHA e `npx --yes` sem lockfile | CI |
| N-27 | Baixa | O CI não compila o Android nem roda o teste de `tool/kan53` **[corrige o A-12]** | CI |
| N-28 | Baixa | Testes Dart dependem do fuso horário da máquina | Testes |
| N-29 | Baixa | Código sem uso; o histórico paginado não está ligado a nenhuma tela | App |
| N-30 | Baixa | O token antigo da football-data.org aparece em mais commits do que o documentado | Segredos |

---

## N-01 — A lista de partidas traz só as 30 primeiras da temporada (Alta)

- **Onde:** `lib/data/firestore/partidas_repository.dart:31-36`.
- **Evidência:** a consulta é `where competitionCode == 'BSA'`, `orderBy startsAtUtc asc`, `limit(limit * 2)` com `limit = 15`, sem filtro de data. O backend grava a temporada inteira em `matches` (a primeira execução do `syncMatches` e uma a cada 6 horas varrem a temporada, `agendaDaSincronizacao.ts:97-105`) e nada apaga partidas antigas. `_ordenarPartidas` só reordena essas 30.
- **Risco:** hoje (19/11/2026) a consulta devolve as primeiras rodadas do campeonato, todas finalizadas. A Home mostra só jogos antigos e Criar Desafio mostra "nenhuma partida disponível": **não dá para criar desafio em partida futura**. Já constava como P-07 na análise anterior; o A-03 resolveu o índice e tirou o fallback, mas não essa limitação. Que `matches` do projeto real tenha a temporada inteira é inferência do código de sincronização; não foi consultado o Firestore real.
- **Correção:** filtrar a janela relevante (`startsAtUtc >= agora - 3 dias`, ordenado, com limite) e, para os encerrados recentes, uma segunda consulta descendente com limite pequeno (precisa de índice `startsAtUtc DESC`); aplicar o mesmo filtro no fallback de cache. Cobrir com teste contra o emulador semeado com passado e futuro.
- **Confiança:** Alta.

## N-02 — Criar Desafio pela Home não carrega amigos nem saldo (Alta)

- **Onde:** `lib/data/firestore/challenge_repository.dart:302-321`; `lib/tela_criar_desafio/tela_criar_desafio.dart:81-108`.
- **Evidência:** `listarAmigosAceitos` lê `users/{outroUid}` de cada amigo; `firestore.rules:28` só permite `get` do próprio documento, e a negação está confirmada pelo teste de regras e pelo `integration_test/jornada_mvp_emulator_test.dart`. Saldo e amigos são buscados no mesmo `try`, e o `setState` só roda depois dos dois.
- **Risco:** com ao menos um amigo, a tela diz "você ainda não possui amigos aceitos", o saldo fica em "Carregando..." e Enviar responde "Selecione um amigo". Só funciona entrando por Perfil > Meus Amigos > Desafiar (que passa o amigo), e mesmo assim sem saldo. Era o P-04 da análise anterior; o A-07 apenas passou a registrar o erro, sem corrigir a causa. Problemas secundários: uma leitura por amigo (N+1), UID usado como `username` quando falta o campo, e `buscarSaldoDisponivel` inventa saldo 1000 quando `saldoTotal` falta.
- **Correção:** usar a callable `getFriends` (já devolve nome e `@username`) em vez de ler `users`; separar o carregamento de saldo e de amigos, cada um com seu erro e mensagem; obter o saldo de `UserProfileService.observarCarteiraAtual()`.
- **Confiança:** Alta.

## N-03 — Testes de emulador com data fixa quebram o CI amanhã (Alta)

- **Onde:** `functions/test/activeChallengeAndExpiration.emulator.test.ts:74-75` e as 21 chamadas a `criarDesafioParaAmigoNaTransacao`/`aceitarDesafioNaTransacao` sem o argumento `agora`.
- **Evidência:** a partida é semeada em `2026-11-20T20:00:00Z` (corte às 19:55) e os desafios são criados com o relógio real (`agora = new Date()`). Confirmado: hoje são 19:53 UTC de 19/11. Os outros arquivos já passam o relógio (`cancelamento.emulator.test.ts`, `challengeFlow.emulator.test.ts`). Os testes 12 e 13, escritos na correção do convite recebido, repetiram o mesmo defeito.
- **Risco:** a partir de 20/11 às 19:55 UTC (16:55 em Brasília) os testes 1 a 13 falham com `partida-no-corte`, e a partir de 21:55 UTC também os da segunda partida. O job "Backend e Security Rules" fica vermelho em todo PR, sem relação com o código, e com a proteção de branch ligada os merges ficam bloqueados.
- **Correção:** passar um relógio fixo (`const CRIACAO = new Date("2026-11-20T12:00:00Z")`) como 4º argumento, como faz `cancelamento.emulator.test.ts`, ou semear as partidas relativas a `Date.now()`.
- **Confiança:** Alta (código e datas lidos; não rodado no emulador).

## N-04 — Prazo de adiamento conta da primeira sincronização (Alta) [corrige o A-01]

- **Onde:** `functions/src/desafios/cancelamento.ts:160-167`; `challengeFirestore.ts:292-297,398`; `functions/src/partidas/match.ts:188`.
- **Evidência:** `originalStartsAtUtc` é a data da primeira vez que a partida foi gravada e nunca muda; a primeira execução varre a temporada, então vale a data provisória do provedor naquele dia. A criação e o aceite só exigem partida `AGENDADA` e antes do corte; não aplicam a regra dos 7 dias. Reproduzido com o código compilado: partida com original em 01/06, remarcada (`AGENDADA`) para 15/07, desafio criado em 10/07 resulta em `MATCH_POSTPONED` para `PENDING` e `ACCEPTED`. Os testes só cobrem desafio criado antes da remarcação. A auditoria de segurança chegou ao mesmo ponto de forma independente.
- **Risco:** partida remarcada mais de 7 dias depois da data da primeira sincronização aparece como próximo jogo, aceita desafio e, na execução seguinte do job (até 5 minutos), o desafio é cancelado, mesmo que ninguém tenha sido afetado por adiamento. A partida fica na prática impossível de apostar, sem erro na criação. Não perde saldo (as reservas voltam). A frequência no Brasileirão é inferência.
- **Correção:** gravar no desafio, na criação, o `startsAtUtc` da partida vigente (campo imutável como `matchId`) e usar `max(originalStartsAtUtc, esse valor)` como base do limite; teste novo com partida já remarcada e desafio posterior. Alternativa, que depende de decisão de negócio: recusar a criação com `partida-invalida` pela mesma conta e filtrar no app.
- **Confiança:** Alta.

## N-05 — Desafio preso se a partida guardada deixa de mudar (Média)

- **Onde:** `cancelamento.ts:162-168`; `iniciarDesafios.ts:25`; `aguardarResultado.ts:29-30`; `partidas/footballData/adapter.ts:158-160`; `sincronizacao.ts:21`.
- **Evidência:** `ACCEPTED` só inicia quando a partida sai de `AGENDADA`; `IN_PROGRESS` só avança quando ela sai de `EM_ANDAMENTO`. A única saída por tempo é para `ADIADA`. Partida com status novo, time inválido, que o provedor parou de atualizar ou que sumiu da resposta continua com o último status, e "partida que some da resposta não é apagada".
- **Risco:** o desafio fica `ACCEPTED` ou `IN_PROGRESS` indefinidamente, as duas reservas ficam presas e o `saldoReservado > 0` bloqueia o bônus de recuperação. O único sinal é um `logger.warn` de partidas descartadas. Não afeta `PENDING`, que expira só pelo horário. É diferente do item de `SUSPENSA`/`REVISAO_NECESSARIA` do A-01. Frequência depende do provedor.
- **Correção:** saída por tempo: `AGENDADA` com `startsAtUtc` mais 7 dias no passado tratada como adiada além do tolerado (cancela e libera); `EM_ANDAMENTO` além de um prazo (por exemplo 24 horas) gera `logger.error` com o ID do desafio ou segue a mesma regra, conforme decisão de negócio. Testes em `cancelamento.test.ts`.
- **Confiança:** Média (o buraco é certo; a frequência é do provedor).

## N-06 — UIDs e IDs de partida crus na interface (Média)

- **Onde:** `card_de_desafios_ativos.dart:148`; `desafios_recebidos_card.dart:95,105`; `desafios_enviados_card.dart:54`; `detalhes_do_desafio_dialog.dart:24,34,37,41`; `desafios_em_aberto_secao.dart`; `desafios_finalizados_secao.dart`.
- **Evidência:** "Aguardando <UID>", "Desafio de <UID>", "Partida #footballdata_123456"; `descricaoPartida` nunca é passada ao modal de aceite. O teste da jornada fixa esse comportamento (`expect(find.text('Aguardando uidBia'), ...)`), e os UIDs legíveis de teste escondem o defeito. O próprio relatório da KAN-107 registra "Aguardando uidBia" como esperado.
- **Risco:** o desafiado reserva BetCoins ao aceitar sem ver quem é o adversário nem qual é o jogo; com "Vitória Mandante" sem os times, o palpite é ambíguo. A interface expõe identificadores internos.
- **Correção:** resolver o nome pelos amigos (`getFriends`) e a partida por `matches/{id}` (legível por usuário logado) ou pelo `PartidasProvider`, passar `descricaoPartida` ("Flamengo x Vasco, 22/11 16:00") e mostrar "Você" para o próprio UID; melhor, gravar nomes e times no desafio na criação. Nos testes, usar UIDs opacos.
- **Confiança:** Alta.

## N-07 — Atualização automática de partidas ignora o cache (Média)

- **Onde:** `lib/telas_principais/home_page.dart:96-101`; `lib/provider/partidas_provider.dart:78`.
- **Evidência:** um `Timer.periodic` de 60 s chama `carregarPartidas(silencioso: true)`, e a chamada silenciosa nunca usa o cache de 60 s. Cada chamada é um `get` do servidor de até 30 documentos. O timer só é cancelado no `dispose` da Home, que continua montada sob Criar Desafio, Perfil e Amigos. Não há observação do ciclo de vida do app nem bloqueio para chamadas simultâneas.
- **Risco:** cerca de 1.800 leituras por hora por sessão aberta (14.400 em 8 h) para um dado que só muda a cada 5 minutos; a cota gratuita diária (50 mil leituras) acaba com poucos usuários. O comportamento em segundo plano é inferência.
- **Correção:** trocar o polling por `snapshots()` na mesma consulta (só documentos alterados são cobrados depois da primeira carga) ou respeitar o TTL no modo silencioso com intervalo de pelo menos 5 minutos, pausar com `WidgetsBindingObserver` e guardar o `Future` em andamento.
- **Confiança:** Alta em primeiro plano; Média em segundo plano.

## N-08 — Testes não cobrem os repositórios reais; relatório da KAN-107 afirma demais (Média)

- **Onde:** `test/jornada_completa_mvp_test.dart`; `test/partidas_futuras_test.dart:7-18`; `integration_test/jornada_mvp_emulator_test.dart`; `docs/entrega-2/validacao-jornada-mvp.md:30,83,118`.
- **Evidência:** os testes usam só repositórios falsos. No teste da jornada, o próprio fake decide o criador, reserva o saldo e calcula o prêmio (`_FakeChallengeRepository`, `resolverPartidaEFinalizarDesafio`); o passo final só verifica o texto "DESAFIOS FINALIZADOS", não 1100 nem 900. O teste de emulador só faz login, lê o próprio perfil e confirma a negação de leitura de terceiros; não cria, aceita nem liquida desafio. `integration_test/` não roda no CI. O relatório declara a integridade dos saldos validada em integração.
- **Risco:** N-01 e N-02 passam pelos 339 testes e pelo CI. Uma regressão no `ChallengeService` ou no payload de uma callable não seria pega. A cobertura real de reserva e liquidação está nos testes de `functions/test/`.
- **Correção:** teste Dart contra o Firestore Emulator para a consulta de `matches` (temporada semeada com passado e futuro) e para `listarAmigosAceitos` com as regras reais, e uma jornada criar, aceitar e cancelar com as Functions no emulador; rodar o grupo no job de emulador do CI. Corrigir o texto do relatório para "navegação com fakes" ou apontar os testes de backend.
- **Confiança:** Alta.

## N-09 — Existência de relação entre terceiros revelada (Média)

- **Onde:** `functions/src/amigos/friendshipFirestore.ts:169-174`; `friendship.ts` (`gerarFriendshipId`, `avaliarAceiteAmizade`).
- **Evidência:** `acceptFriendRequest` e `rejectFriendRequest` recebem um `friendshipId` do cliente, que é previsível (`${userAId}_${userBId}` com UIDs ordenados, e a busca pública fornece UIDs). Documento inexistente responde `not-found`; documento de que o solicitante não participa responde `permission-denied`.
- **Risco:** qualquer usuário autenticado descobre se duas outras pessoas têm uma relação registrada (pendente, aceita ou recusada), dado cuja leitura direta as Security Rules proíbem. Nenhuma alteração indevida foi encontrada.
- **Correção:** responder do mesmo jeito (código, mensagem e `details`) para inexistente e para não participante; só distinguir estado e papel depois de confirmar a participação. Vale para aceite e recusa.
- **Confiança:** Alta.

## N-10 — Criar e cancelar desafio em ciclo, sem limite de uso (Média)

- **Onde:** `challengeFirestore.ts:204-213,310-328`; `cancelamento.ts:113-125`.
- **Evidência:** `temDesafioAtivoNaPartida` lê todo o histórico do usuário na partida e só descarta terminais em memória; o cancelamento pelo criador devolve a reserva inteira, permitindo repetir a criação; só a busca tem limite de uso.
- **Risco:** com amizade, partida futura e 10 BetCoins, um usuário alterna criar e cancelar sem gastar saldo, deixando um desafio terminal e dois lançamentos por ciclo; a verificação seguinte lê tudo de novo, e o histórico também entra nas verificações do outro participante. O volume que causa timeout não foi medido.
- **Correção:** consulta só dos candidatos ativos (filtros adequados e limite de existência), preservando a atomicidade e a exceção do convite recebido; limite transacional de criação e cancelamento por usuário, reaproveitando `core/limiteDeUso.ts`.
- **Confiança:** Alta.

## N-11 — Caixa de solicitações de amizade sem limite (Média)

- **Onde:** `friendshipFirestore.ts:63-78,303-328`; `getFriendRequests.ts`.
- **Evidência:** o envio exige perfil do destinatário, mas não do remetente, e não há limite de envio, de pendências nem de reabertura após recusa. A listagem lê todas as pendências do usuário e todos os perfis remetentes, sem paginação.
- **Risco:** várias contas podem lotar a caixa de uma vítima, que não consegue apagar as solicitações, e cada atualização lê tudo. O custo cresce, mas a indisponibilidade por tamanho é inferência (sem teste de carga).
- **Correção:** paginar no servidor, exigir perfil do remetente e impor cotas de envio e reabertura (mesmo mecanismo do N-10).
- **Confiança:** Alta para o crescimento; Média para a indisponibilidade.

## N-12 — Configuração de segurança e de agenda em arquivo ignorado pelo git (Média)

- **Onde:** `.gitignore:60-61` (`.env.*`); `functions/src/core/appCheck.ts:22-26`; `docs/callable-functions.md:289`.
- **Evidência:** `ENFORCE_APP_CHECK` e `PARTIDAS_SYNC_*` são lidos de `functions/.env.betfriends-unirv-2026`, que a documentação manda criar e que o `.gitignore` ignora; neste clone ele não existe.
- **Risco:** depois que o App Check for ligado, qualquer integrante que publique a partir de um clone limpo implanta todas as callables com `enforceAppCheck: false`, sem erro nem aviso; a agenda da sincronização também volta ao padrão. A documentação registra deploys por contas diferentes.
- **Correção:** versionar `functions/.env.<projeto>` (não contém segredo) com exceção explícita no `.gitignore`, ou fazer o deploy falhar quando o arquivo faltar para o projeto de produção.
- **Confiança:** Alta no mecanismo; o impacto depende de a exigência ser ligada.

## N-13 — Documentação desatualizada (Média) [corrige o A-03 e o A-08]

- **README:** diz que há quatro funções publicadas (há 14), que "amizades e desafios reais ainda não chegaram ao app", que as regras só deixam ler o próprio perfil, que o app chama a API diretamente e atualiza a cada 30 s, e lista como pendente o que existe (amizades, criar e aceitar, tela de créditos); a estrutura não cita `tela_amigos/`, `tela_sobre/` nem `functions/src/amigos/`. A revisão pedida como pendência do A-08 não foi feita.
- **`docs/callable-functions.md` §10:** diz que nada cria desafios em produção e mantém a B-4 como pendência para liquidar em produção ("o resultado pago vem de `score.winner`, sem conferência com o placar"), mas as callables de desafio já estão publicadas e o código continua usando só `score.winner` (`partidas/footballData/resultado.ts:24-28`). Com isso o `syncMatches` já liquida desafios reais sem essa conferência. Falta registrar a B-4 como decisão explícita; se não for aceita, conferir `winner` contra `fullTime.home/away` e deixar o desafio aguardando em caso de divergência.
- **`docs/firestore-schema.md` §6:** diz que `firestore.indexes.json` continua vazio (tem 6 índices desde o A-03), recomenda índices diferentes dos declarados e descreve o `PartidaModel` no formato do provedor.
- **Correção:** reescrever o estado atual com os fatos de 19/11 e alinhar as tabelas.
- **Confiança:** Alta.

## N-14 — Itens de release ausentes (Média)

- **Evidência:** não há `LICENSE`, `CHANGELOG` nem política de privacidade; não há exclusão de conta (nenhum `deleteUser` ou fluxo equivalente em `lib/` ou `functions/src`); `pubspec.yaml:19` segue `1.0.0+1`; `android:label="betfriends"` em minúsculas. O app coleta e-mail, nome e username e o repositório é público.
- **Risco:** a Google Play exige política de privacidade e exclusão de conta dentro do app para apps com conta; a LGPD exige informar o tratamento e atender eliminação; o Play Integrity do §12 só funciona com distribuição pela Play; sem incremento de `versionCode` o mesmo número não é aceito duas vezes; sem licença o código público é "todos os direitos reservados"; apostas simuladas exigem declaração de classificação etária. A exigência imediata depende de haver publicação na Play.
- **Correção:** política de privacidade ligada à tela de Informações; callable `deleteAccount` tratando carteira, desafios ativos e ledger; `CHANGELOG.md`, `LICENSE` (ou declaração explícita) e incremento de versão por release.
- **Confiança:** Alta na ausência; Média na exigência.

## N-15 — `jornada_mvp_emulator_test.dart` depende da ordem dos arquivos (Média)

- **Evidência:** a jornada espera o nome "Ana Lima" para `uidAna`; `user_profile_emulator_test.dart` renomeia `uidAna` para "Ana Souza" e não restaura. `flutter test integration_test/` roda os arquivos na mesma sessão e a ordem não é garantida. O comentário de execução do arquivo cita `npm --prefix functions run emulators:exec`, script que não existe, e o arquivo não está no `integration_test/README.md`.
- **Risco:** o resultado muda conforme a ordem do sistema de arquivos. Não foi executado (exige dispositivo), mas a mutação e a ordem foram conferidas.
- **Correção:** contas exclusivas no seed (por exemplo `uidAnaJornada`), comando correto no comentário e entrada no README.
- **Confiança:** Alta na dependência; Média na ordem exata em outras máquinas.

## N-16 a N-30 (Baixa)

- **N-16 — O job `syncMatches` aborta antes de processar resultados** (`sincronizacao.ts:108-118`; `syncMatches.ts:37-45`). Um erro inesperado numa das até 20 transações paralelas de gravação de partida sai antes de `processarResultados` e de `registrarExecucao`, contra o que `callable-functions.md` §10 afirma. Atraso de 5 minutos ou mais, sem perda de saldo. Correção: `processarResultados` num `finally` e falha de uma partida tratada isoladamente.
- **N-17 — Partida trocada em silêncio** (`tela_criar_desafio.dart:111-132,336-342`). `_reconciliarSelecao` escolhe a primeira elegível quando a selecionada atinge o corte, e qualquer rebuild dispara isso: o usuário envia um desafio, com BetCoins reservadas, para outra partida. Correção: limpar a seleção e avisar.
- **N-18 — Botão sem trava** (`desafios_enviados_card.dart:82-84`; `modal_aceitar_desafio.dart:183-186`). CANCELAR fica sempre ativo e o segundo toque recebe "não está mais pendente" depois do verde; o modal de aceite fecha por "X", arraste ou toque fora durante o envio. Sem perda de saldo (o backend é transacional). Correção: conjunto de IDs em andamento e `PopScope`.
- **N-19 — Listener lê o histórico inteiro** (`challenge_repository.dart:270-277`). Sem `limit` nem `orderBy`; a Home lista todos os terminais em ordem do ID. Correção: não terminais por `status in`, terminais por `updatedAt` desc com limite, e índices.
- **N-20 — Erro vira dado demonstrativo** (`home_page.dart:275`; `card_de_desafios_ativos.dart:94-97`). Com `permission-denied` ou erro interno os desafios reais somem e aparecem exemplos fixos, sem mensagem nem nova tentativa. Correção: estados carregando, erro com "Tentar novamente" e vazio, e tirar o demonstrativo do caminho de produção.
- **N-21 — `registrarErro` pode não aparecer em release** (`registro_de_erros.dart:11-18`) **[corrige o A-07]**. `dart:developer log` não chega ao logcat no Android e não há VM service em release; `main.dart` não define `FlutterError.onError` nem `PlatformDispatcher.onError`. Confiança Média (baseada em issues do Flutter, não reproduzida em aparelho). A afirmação do A-07 de que o erro aparece no logcat deve ser relativizada. Correção: `debugPrint` em debug e Crashlytics ou, no mínimo, os handlers globais em release.
- **N-22 — Backup e dados após o logout** (`AndroidManifest.xml:3-6`; `auth_provider.dart:61-73`). `allowBackup` no padrão (ligado), sem `dataExtractionRules`; o logout só chama `signOut`, e o cache do Firestore com saldos e desafios fica em disco. Correção: `android:allowBackup="false"` ou regras de extração e, no logout, `terminate()` e `clearPersistence()`. Confiança Média.
- **N-23 — Acessibilidade.** Nenhum `Semantics` em `lib/`; 12 `GestureDetector` funcionam como botão (palpites do modal de aceite, "Atualizar", detalhes); áreas abaixo de 48 dp; texto `#64748B` em 11 px sobre `#151E2E` com cerca de 3,5:1 (mínimo AA 4,5:1). Correção: `InkWell`, `ChoiceChip` ou `Semantics`, área mínima e cores mais claras.
- **N-24 — Busca fora de ordem** (`tela_buscar_usuarios.dart:92-108`). Uma resposta antiga pode substituir a mais nova. Correção: contador de requisição.
- **N-25 — Dependências.** `npm audit` (`fast-xml-parser`, `glob`, `minimatch`, entre outras): 7 vulnerabilidades transitivas, todas com correção por `npm audit fix`, impacto prático baixo; FlutterFire uma major atrás (`cloud_firestore` 6.10 para 7.2, `firebase_auth`, `firebase_core`, `cloud_functions`, `firebase_app_check`); plugin `google-services` em 4.3.15; sem `.github/dependabot.yml`.
- **N-26 — Cadeia de suprimentos do workflow.** Actions por tag e não por SHA (`subosito/flutter-action` é de terceiro), `npx --yes firebase-tools@15.32.1` resolve as dependências transitivas sem lockfile, e `checkout` mantém `persist-credentials`. O impacto é limitado por `permissions: contents: read`, `pull_request` e ausência de segredos.
- **N-27 — Lacunas do CI** [corrige o A-12]. Não compila o Android (`flutter build apk --debug`) e não roda `tool/kan53/medicao.test.mjs`; uma quebra de Gradle ou de plugin só aparece na máquina de quem gera o APK.
- **N-28 — Testes Dart dependem do fuso** (`test/partidas_futuras_test.dart:66,90`). Reproduzido: com `TZ=Asia/Tokyo`, 2 testes falham; passam em UTC e em Brasília. Correção: calcular a data esperada com `toLocal()`.
- **N-29 — Código sem uso.** `historico_de_desafios_service.dart` e `lib/data/firestore/firestore_service.dart` não têm importador; `firebase_options.dart` não é importado (a inicialização depende do `google-services.json`). O histórico paginado (KAN-88 a 91) não está ligado a nenhuma tela, embora o relatório da KAN-107 o dê como "Implementado".
- **N-30 — Token antigo no histórico.** Além do commit citado (`8462ffe`), aparece em `8f685f7` (02/11/2026, dentro de um teste negativo) e só sai em `34fd242`. Repositório público. A revogação no provedor não é verificável pelo repositório; confirmar no painel e citar todos os commits. Nenhum outro padrão de segredo foi encontrado.

---

## O que foi examinado e está correto

1. **Identidade e payload:** todas as callables tiram o UID do token; campos extras do payload não substituem a identidade; só os nomes do contrato são aceitos (A-09).
2. **Ledger e liquidação:** atômicos, com IDs determinísticos; reexecutar o `syncMatches` não paga de novo; pot de 2x sem taxa; cada estado terminal encerra as reservas.
3. **Transações:** leituras antes das gravações em criação, aceite, recusa, cancelamento, expiração, finalização e bônus.
4. **Cadastro e bônus:** perfil, username e saldo inicial atômicos (reenvio não dá outros 1.000); bônus de recuperação sem data nem valor vindos do cliente.
5. **Security Rules:** `affectedKeys()` impede alterar campos financeiros junto com `displayName`; perfis, ledger e relações de terceiros protegidos na leitura direta.
6. **Respostas públicas:** busca e listas projetam só campos públicos; sem e-mail, saldo ou ledger.
7. **Provedor externo:** mapeamento cobre os 9 status do enum v4; status e resultado desconhecidos viram descarte, nunca valor inventado; resposta atrasada é ignorada; partida finalizada não regride; falhas do provedor não gravam lixo.
8. **Segredo e desenvolvimento:** token só no backend; erros HTTP sanitizados; reposição de BetCoins só em `demo-*` com emulador local.
9. **CI:** `pull_request` (não `pull_request_target`), permissões mínimas, sem segredo, cache do emulador por versão; Node 22 e Flutter 3.47.5 consistentes entre CI, `.nvmrc`, `engines` e documentação.
10. **Pacote de deploy:** `test` e `dev` ficam fora do envio; lockfiles em sincronia; `key.properties`, `*.jks` e logs ignorados.
