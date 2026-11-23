# Achados da Auditoria

Convenção: **Status** começa como `Aberto`; ao corrigir, trocar para `Corrigido (PR #N)`.

---

## A-01 — Fundos reservados podem ficar presos

- **Severidade:** Alta
- **Status:** Corrigido no código (branch `fix/A-01-cancelar-rejeitar-desafio`) e publicado, exceto o item 4 (suspensa e em revisão), que depende de decisão de negócio.
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

### O que foi feito

- `rejectChallenge` e `cancelChallenge` (callables) e o cancelamento pela partida (`processarResultados`), em `functions/src/desafios/cancelamento.ts`. Cada um libera as reservas e muda o estado na mesma transação. Contrato em `docs/callable-functions.md` §11 e `docs/firestore-schema.md` §3.5.
- `ACCEPTED` passa a `IN_PROGRESS` com a partida em qualquer status que já saiu de campo (`INICIA_DESAFIO`); o teste que fixava o comportamento antigo foi atualizado.
- App: botão **Recusar** no modal de aceite e seção **Desafios enviados** na Home com **Cancelar** (com confirmação); desafios cancelados mostram o motivo.
- **Bug encontrado no caminho:** `expirarDesafioNaTransacao` gravava o desafio antes de ler a reserva, o que o Firestore recusa ("reads before writes"). Desafios pendentes nunca expiravam e a reserva do criador não voltava. Estavam falhando 3 testes de emulador (6, 9 e 10 de `activeChallengeAndExpiration`); a ordem foi corrigida.
- Extraída a tabela de erros duplicada das callables de desafio (`desafios/errosHttps.ts`), o que adianta parte do A-09.

### Pendências do A-01

- ~~Funções sem permissão de invocação.~~ Resolvido: o Matheus deu a permissão (`run.services.setIamPolicy`) e o deploy foi refeito.
- Confirmar com o Plano Mestre a regra de adiamento (limite de 7 dias da data original). É uma inferência de RN-MAT-007/008; a constante é `DIAS_DE_ADIAMENTO_TOLERADO`.
- Partida `SUSPENSA` ou `REVISAO_NECESSARIA` continua mantendo o desafio em `WAITING_RESULT` sem prazo de saída (item 4 acima): precisa de decisão de negócio.
- ~~Falha pré-existente, fora do A-01: `activeChallengeAndExpiration` teste 5.~~ Corrigida na branch `fix/convite-recebido-nao-e-desafio-ativo`: convite `PENDING` recebido deixou de contar como desafio ativo para o desafiado (D-SCH-11), com testes novos de regra e de concorrência. A suíte de emulador passa inteira.

---

## A-02 — `getMatchesRest` público e sem proteção

- **Severidade:** Alta
- **Status:** Corrigido no código (branch `fix/A-02-remover-getmatchesrest`), removendo o endpoint. Nada a apagar no projeto real: a função nunca foi publicada.
- **Onde:** `functions/src/partidas/getMatchesRest.ts:12`, `lib/services/api/partidas_rest_service.dart`, `lib/tela_academica/`

### O que foi encontrado

`onRequest({ cors: true })` sem autenticação, sem App Check e sem limite de uso. Cada chamada lê até 50 documentos de `matches`. O `maxInstances: 10` global limita só a concorrência, não o volume. O `catch` interno devolve valores padrão (`"Mandante"`, `"BSA"`, `2026`) quando um documento está corrompido, escondendo dado inválido.

### Risco

Custo de leitura do Firestore por abuso. Dado corrompido mascarado como válido.

### Correção proposta

- Exigir App Check ou ID token, ou remover o endpoint do deploy depois da entrega acadêmica.
- Restringir `cors` aos origens necessários.
- Remover o fallback silencioso; registrar em log e omitir o documento inválido.

### O que foi feito

Decisão do responsável: o endpoint não é mais exigido pela atividade acadêmica, então foi **removido** em vez de protegido. Saíram a função `getMatchesRest` (`functions/src/partidas/getMatchesRest.ts` e o export em `index.ts`), o cliente `PartidasRestService`, a tela `TelaPartidasRest`, os dois atalhos para ela (menu da conta na Home e botão no Perfil) e os testes dessas peças. O app continua lendo `matches` direto do Firestore (`PartidasRepository`), por isso o índice composto de `matches` (A-03) continua necessário.

### Pendência do A-02

Nenhuma. Em 19/11/2026, `functions:list` no projeto real mostrou que `getMatchesRest` nunca chegou a ser publicada (só existiam `systemPing`, `createUserProfile`, `claimRecoveryBonus` e `syncMatches`), então não havia função para apagar e o endpoint nunca ficou público. A instrução anterior de rodar `functions:delete` estava errada.

---

## A-03 — Índices compostos ausentes

- **Severidade:** Alta
- **Status:** Corrigido no código (branch `fix/A-03-indices-firestore`). Falta publicar: `firebase deploy --only firestore:indexes` e conferir no console que os índices ficaram `Enabled`. Até lá, `getMatchesRest` e a lista de partidas do app falham em produção se os índices não existirem.
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
- **Status:** Corrigido no código (branch `fix/A-04-assinatura-release`). Falta gerar o keystore real e criar `android/key.properties` (ação manual, ver `README.md` "Build de release"). Sem o arquivo, o release continua assinado com a chave de debug.
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
- **Status:** Corrigido no código (branches `fix/A-05-app-check-busca` e `fix/A-05-enforce-app-check-env`) e publicado. App Check fica enviado pelo app e **não exigido** pelo backend (decisão de configuração, ver pendências).
- **Onde:** `functions/src/core/callable.ts`, `functions/src/perfil/searchUsers.ts`

### O que foi encontrado

Nenhuma callable usa `enforceAppCheck`. `searchUsers` faz busca por prefixo em `users` e devolve até 50 registros. Qualquer conta autenticada pode enumerar todos os usuários com prefixos curtos. Não há limite de chamadas por usuário. Prefixo de 1 caractere é aceito.

### Risco

Enumeração de usuários e uso abusivo das funções por clientes não oficiais.

### Correção proposta

- Habilitar App Check no app e `enforceAppCheck: true` em `authedCallable` (opção configurável para o emulador).
- Exigir mínimo de 2 ou 3 caracteres na busca.
- Avaliar limite de taxa por UID.

### O que foi feito

- **App Check:** o app envia o token em toda chamada (`firebase_app_check`, ativado em `main.dart`; provedor de depuração em debug e Play Integrity em release; fora dos emuladores). Todas as callables passam por `authedCallable`, que lê o parâmetro `ENFORCE_APP_CHECK` (padrão `false`). Ligar é configuração de deploy, não código; passos em `docs/callable-functions.md` §12.
- **Busca:** só consulta com 3 caracteres ou mais (o mínimo de um username), no máximo 20 resultados, e o app nem chama o backend com termo menor.
- **Limite de uso:** 60 buscas por minuto por usuário (`core/limiteDeUso.ts`, contador em `rateLimits/{funcao}_{uid}`, `resource-exhausted` acima disso). O mecanismo serve a qualquer outra callable.
- Teste de Security Rules que já falhava (`o índice composto da consulta está declarado`) estava desatualizado desde que `challenges` ganhou mais índices; passou a checar só o índice do histórico.

### Pendências do A-05

- **Exigir** o App Check é decisão e configuração fora do código, e **não deve ser ligado se o app não for publicado na Google Play**: o Play Integrity não atesta APK instalado à mão e a exigência derrubaria o app. Enquanto isso, o app envia o token e o backend o ignora.
- `searchUsers` foi publicada em 19/11/2026 sem a permissão de invocação (`403 run.services.setIamPolicy`); o Matheus deu a permissão e o deploy foi refeito, então o limite e o mínimo da busca já valem.
- Correção feita durante o deploy: `ENFORCE_APP_CHECK` era um parâmetro do Firebase (`defineBoolean`), que o SDK não aceita em `enforceAppCheck` e que fazia o deploy sem terminal parar pedindo valor. Passou a variável de ambiente (`functions/.env.<projeto>`), como as da sincronização.

---

## A-06 — `syncMatches` varre desafios em série

- **Severidade:** Média
- **Status:** Corrigido no código (branch `perf/A-06-sync-desafios`).
- **Onde:** `functions/src/partidas/syncMatches.ts:33-34`, `functions/src/desafios/expirarDesafios.ts`, `iniciarDesafios.ts`, `aguardarResultado.ts`

### O que foi encontrado

A cada 5 minutos, com `timeoutSeconds: 240` e `maxInstances: 1`, o job lê todos os desafios `PENDING`, `ACCEPTED`, `IN_PROGRESS` e `WAITING_RESULT` e abre uma transação por desafio, em série. Cada passo relê a partida.

### Risco

Com mais desafios, o job estoura o timeout, o processamento de resultados atrasa e a liquidação também.

### Correção proposta

- Agrupar por `matchId` e ler cada partida uma vez.
- Filtrar por partidas que mudaram de estado, em vez de varrer tudo.
- Limitar concorrência (por exemplo, lotes paralelos pequenos) e registrar duração por etapa.

### O que foi feito

- `processarResultados` faz uma consulta dos desafios não terminais e um `getAll` das partidas distintas. As etapas reutilizam esse contexto; chamadas isoladas das etapas continuam funcionando.
- Cancelamento, expiração, início e espera filtram candidatos em memória antes de abrir transações. A transação relê desafio e partida e revalida a regra; liquidação, reservas e ledger continuam atômicos e idempotentes.
- Os passos que só mudam o estado do desafio (iniciar e aguardar resultado) processam até cinco por vez, isolando falhas. Os que mexem em carteiras (expirar, cancelar pela partida e liquidar) continuam **um por vez** (`CONCORRENCIA_COM_CARTEIRA`): os mesmos amigos aparecem em vários desafios e as transações disputariam os mesmos `users/{uid}`. O contexto só avança depois do commit, permitindo `ACCEPTED → IN_PROGRESS → WAITING_RESULT → FINISHED` na mesma execução.
- Logs por etapa incluem duração em milissegundos e contagens; casos suspensos/em revisão continuam aguardando e sendo registrados.
- A varredura continua proporcional ao número de desafios não terminais, mas desafios sem mudança não abrem transações. Desafios criados depois do instantâneo ficam para a próxima execução; o instantâneo nunca autoriza uma gravação sem revalidação.
- Medição no Firestore Emulator com 12 desafios sem mudança (três de cada status não terminal), todos na mesma partida: revisão-base com **9 transações e 11 leituras de partida** por execução; implementação nova com **0 transações e 1 leitura de partida**. O teste permanente também confere que nenhum estado muda; testes adicionais cobrem o limite de concorrência, isolamento de falhas e revalidação após mudança da partida.

---

## A-07 — `catch (_)` genéricos no cliente

- **Severidade:** Média
- **Status:** Corrigido no código (branch `fix/A-07-erros-cliente`).
- **Onde:** `lib/app.dart:47`, `lib/data/firestore/challenge_repository.dart`, `friendship_repository.dart`, `partidas_repository.dart`, `user_profile_repository.dart`, `user_search_repository.dart`, `lib/models/friendship_model.dart`, `lib/provider/auth_provider.dart`, `lib/services/api/partidas_rest_service.dart`, `lib/tela_amigos/tela_buscar_usuarios.dart`

### O que foi encontrado

Mais de 20 blocos `catch (_)`. Em `app.dart:47`, falha ao criar `ChallengeService` vira `null` em silêncio.

### Risco

Falhas reais (permissão, índice, rede, dado inválido) viram comportamento degradado sem registro, o que dificulta o diagnóstico.

### Correção proposta

- Tratar cada caso: capturar tipos específicos (`FirebaseException`, `FormatException`), registrar com `debugPrint`/log e propagar erro de domínio.
- Remover o `try/catch` de `app.dart` e injetar o serviço corretamente.

### O que foi feito

Eram 32 `catch (_)` no app (a contagem inicial de "mais de 20" estava baixa); não sobrou nenhum. O cliente e a tela de REST listados no achado já tinham saído no A-02.

- **`registrarErro`** (`lib/services/registro_de_erros.dart`): registra contexto, erro e pilha via `dart:developer` (console do `flutter run`, logcat, DevTools), sem mudar a mensagem mostrada ao usuário. Todo catch genérico que sobrou como rede de segurança da tela passou a registrar antes de mostrar a mesma mensagem de antes.
- **`app.dart`:** o `ChallengeService` é criado direto, sem o `try/catch` que o transformava em `null` em silêncio.
- **Leituras que fingiam dado ausente:** `buscarSaldoDisponivel` e `listarAmigosAceitos` (desafios) devolviam `null` e lista vazia em qualquer falha; agora lançam `ChallengeException` com o código correto (`permissionDenied`, `unavailable`...). O único chamador (`tela_criar_desafio`) já capturava e registra o erro.
- **Cache de partidas:** registra o erro original do servidor e o do cache, e relança o original se o cache não ajudar.
- **`Carteira.fromMap`:** só `FormatException` é tratada; outro erro deixa de ser escondido.
- **`tela_criar_desafio`:** a escolha da partida no `build` não depende mais de exceção do `firstWhere`.
- Testes novos: erros de leitura do Firestore (`test/firestore_erros_test.dart`) e criação do `ChallengeService` em `test/widget_test.dart`.

### Pendências do A-07

Nenhuma.

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
- **Status:** Corrigido no código (branches `fix/A-01-cancelar-rejeitar-desafio` e `refactor/A-09-payload-desafios`). Falta publicar as duas callables.
- **Onde:** `functions/src/desafios/createChallenge.ts`, `functions/src/desafios/acceptChallenge.ts`

### O que foi encontrado

- `createChallenge` aceita `challengedId`/`friendId`/`desafiadoId` e `challengerPrediction`/`prediction`/`palpite`. `acceptChallenge` aceita `challengedPrediction`/`prediction`/`palpite`. O app usa um só nome.
- A tabela `CODIGO_HTTPS` e o bloco de tradução de erros estão copiados nos dois arquivos.

### Correção proposta

- Manter só os nomes que o app usa (confirmar em `lib/data/firestore/challenge_repository.dart`) e atualizar `docs/callable-functions.md`.
- Extrair a tradução de erros de desafio para um módulo compartilhado.

### O que foi feito

A tabela de erros já tinha sido extraída (A-01). Agora a leitura do payload das duas callables saiu para `desafios/payload.ts` (`lerCriacaoDeDesafio`, `lerAceiteDeDesafio`, com `requirePalpite` compartilhado) e só aceita os nomes que o app envia, conferidos em `lib/models/challenge_model.dart`; os apelidos `friendId`, `desafiadoId`, `prediction` e `palpite` saíram. Teste novo: `functions/test/payloadDeDesafio.test.ts`. As mensagens para campo ausente passaram a ser as de `requireString`/`requireInt`, iguais às das demais callables; o código de erro (`invalid-argument`) e `motivo: "palpite-invalido"` não mudaram.

### Pendências do A-09

Publicar `createChallenge` e `acceptChallenge` (`firebase deploy --only functions:createChallenge,functions:acceptChallenge`). O app atual envia só os nomes canônicos, então não há risco para quem já usa a versão nova; um app antigo que usasse apelidos deixaria de funcionar, mas nenhum foi distribuído.

---

## A-10 — Código morto ou legado no app

- **Severidade:** Baixa
- **Status:** Corrigido no código (branch `refactor/A-10-remover-apiclient`).
- **Onde:** `lib/services/api/api_client.dart`, `lib/services/api/partidas_service.dart`, `lib/app.dart`

### O que foi encontrado

- `ApiClient` não é instanciado em produção, apenas definido. O fluxo `_getPartidasFromClient` do `PartidasService` (consulta direta à Football-Data, KAN-105) só roda com cliente injetado em teste.
- Parâmetro `apiKey` marcado como `@Deprecated`.
- `app.dart` tem um bloco grande de `App` comentado e comentários com nomes de pessoas.

### Correção aplicada ao fluxo de partidas

Removidos o cliente HTTP legado, suas exceções e os parâmetros de cliente/chave do serviço. `PartidasService` consulta exclusivamente o repositório Firestore (RNF-005, RN-SEC-003), sem fallback para o provedor externo. A dependência direta de `http` foi removida do app.

Os testes de consulta direta e fallback HTTP foram excluídos (3 removidos, 15 migrados). Cache, navegação sem consultas duplicadas, atualização explícita e mensagens amigáveis permanecem cobertos com repositório fake e erros do Firestore. O contrato de segurança também verifica que o construtor não aceita chave de API.

`app.dart` perdeu o bloco comentado de uma segunda `App` (para "testar Homepage") e os comentários com nomes de pessoas. `http` saiu das dependências diretas; continua como dependência transitiva de pacotes do Firebase.

---

## A-11 — Arquivos grandes e nomes fora do padrão

- **Severidade:** Baixa
- **Status:** Corrigido no código (branch `refactor/A-11-nomes-snake-case`) para os nomes e os quatro maiores arquivos. Restam arquivos de 400 a 700 linhas (ver pendências).
- **Onde:** `lib/telas_principais/homePage.dart` (918 linhas), `lib/tela_criar_desafio/tela_criar_desafio.dart` (911), `lib/widgets_homePage/cardDeDesafiosAtivos.dart` (668), `lib/tela_perfil/tela_perfil.dart` (720)

### O que foi encontrado

Seis arquivos violam `file_names` (único aviso do `flutter analyze`): `homePage.dart`, `appbarDasPartidas.dart`, `cardDeCarteira.dart`, `cardDeDesafio.dart`, `cardDeDesafiosAtivos.dart`, `cardDePartidas.dart`. Telas e widgets grandes misturam layout, estado e formatação.

### Correção proposta

- Renomear para `snake_case` com `git mv` e atualizar imports, em um commit isolado.
- Extrair widgets menores dos arquivos acima, sem mudar comportamento.

### O que foi feito

- **Nomes:** os seis arquivos e a pasta `widgets_homePage/` passaram para `snake_case` (`home_page.dart`, `widgets_home_page/appbar_das_partidas.dart`, `card_de_carteira.dart`, `card_de_desafio.dart`, `card_de_desafios_ativos.dart`, `card_de_partidas.dart`) com `git mv`, em commit isolado. `flutter analyze` ficou com **zero** avisos.
- **Extração de widgets**, sem mudar comportamento (mesmas chaves, textos e API pública; os 340 testes seguem passando):

| Arquivo | Antes | Depois | Extraído |
|---|---|---|---|
| `telas_principais/home_page.dart` | 893 | 373 | lista de partidas, cabeçalho, menu da conta, barra de navegação e alerta de pendentes |
| `tela_criar_desafio/tela_criar_desafio.dart` | 913 | 424 | seletores de amigo, partida, palpite e valor, saldo e botão de envio |
| `widgets_home_page/card_de_desafios_ativos.dart` | 827 | 172 | seções de recebidos, enviados, em aberto, finalizados, estados vazio e demonstrativo, e detalhes |
| `tela_perfil/tela_perfil.dart` | 701 | 158 | dados, cabeçalho, diálogo de edição de nome e avisos |

### Pendências do A-11

Ficam sem divisão, por serem menores e com estado mais entrelaçado: `tela_buscar_usuarios.dart` (~690 linhas), `tela_lista_amigos.dart` (~570), `tela_comunicacoes_amizade.dart` (~520), `cadastro_page.dart` (~460), `card_de_partidas.dart` (~395) e `modal_aceitar_desafio.dart` (~385). Podem seguir o mesmo caminho se o grupo quiser.

---

## A-12 — Sem CI

- **Severidade:** Baixa
- **Status:** Corrigido no código (branch `ci/A-12-github-actions`). Falta ligar a proteção de branch e ver a primeira execução.
- **Onde:** `.github/workflows/ci.yml` (novo)

### O que foi encontrado

Nada executa `flutter analyze`, `flutter test` ou `npm test` automaticamente nos pull requests. Os testes de regras e de emulador dependem de execução manual.

### Correção proposta

Workflow no GitHub Actions com `flutter analyze`, `flutter test` e, em `functions/`, `npm ci` + `npm test`. Testes de emulador em job separado.

### O que foi feito

`.github/workflows/ci.yml`, com três jobs independentes que rodam em pull requests e pushes para `qas` e `main`, sem segredo e sem tocar o Firebase real: **App Flutter** (`flutter analyze` sem nenhum aviso e `flutter test`, Flutter 3.47.5), **Functions** (`npm ci` e `npm test`, Node 22 de `functions/.nvmrc`) e **Backend e Security Rules** (testes de `functions/` e de `tests/firestore-rules/` no Firestore Emulator, JDK 21 e `firebase-tools@15.32.1` pelo npm, com o emulador em cache). Uma execução nova na mesma branch cancela a anterior; permissões mínimas (`contents: read`). O README ganhou a seção de CI e perdeu a tabela de resultados de 01/11, que estava desatualizada.

### Pendências do A-12

- **Exigir os checks para o merge** é configuração do GitHub, não do repositório: *Settings → Branches → Branch protection rules → `qas` → Require status checks to pass* e marcar os três jobs (só aparecem na lista depois da primeira execução). Sem isso o CI avisa, mas não bloqueia.
- O workflow só foi validado aqui por sintaxe e pela execução local dos mesmos comandos; a primeira execução real é a do pull request desta branch. Se algum job falhar por diferença de ambiente do GitHub (versão do Flutter, cache do emulador), ajustar o `ci.yml`.
- `integration_test/` (Android) não roda no CI.

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
