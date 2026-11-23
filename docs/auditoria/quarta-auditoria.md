# Quarta Auditoria Técnica: o que faltava para o MVP e o que foi feito

| Campo | Valor |
|---|---|
| Data | 2026-11-23 |
| Base | branch `qas` em `90207cb` |
| Escopo | Requisitos funcionais RF-001 a RF-021, achados abertos da terceira auditoria, release e operação, documentação |
| Método | Leitura de código e documentos, `flutter analyze`, `flutter test` e a suíte do backend no emulador. Não houve execução em dispositivo, o Jira não estava acessível e nada foi lido ou gravado no Firestore de produção pela auditoria |
| Origem | O planejamento aprovado pelo responsável (`docs/planejamento-mvp-final.md`, na branch `feature/auditoria-correcao-mvp`) |

## Resultado das verificações

| Verificação | Antes (qas em `90207cb`) | Com todas as branches da rodada juntas |
|---|---|---|
| `flutter analyze` | sem problemas | sem problemas |
| `flutter test` | 369 aprovados | 457 aprovados |
| Backend no Firestore Emulator | 469 de 469 | 537 de 537 |
| Testes de regras (`tests/firestore-rules`) | não executados nesta auditoria | 86 de 86 (rodados na branch de exclusão de conta) |
| `integration_test/` e jornada em dispositivo | não executados | não executados |

"Com todas as branches juntas" é uma verificação descartável: as sete branches foram combinadas num worktree temporário, que foi apagado depois; nada foi mesclado nas branches reais. O único conflito foi textual, em `docs/callable-functions.md` (duas seções novas), e não afeta o código.

## Requisitos funcionais

| RF | Antes | Agora |
|---|---|---|
| RF-006 remover amizade | Não existia | Callable `removeFriend` e botão na lista de amigos (branch `feature/rf-006-remover-amizade`) |
| RF-019 extrato | Sem tela | Tela de extrato no Perfil e índice novo (branch `feature/rf-019-extrato`) |
| RF-020 bônus de recuperação | Sem tela | Ação na Home (branch `feature/rf-020-bonus-recuperacao`) |
| RF-021 histórico | Serviço sem tela | Tela paginada (branch `feature/rf-021-historico`) |
| Exclusão de conta (N-14) | Não existia | Callable `deleteAccount` e diálogo no Perfil (branch `feature/exclusao-de-conta`) |

Os demais RF (001 a 005 e 007 a 018) já estavam completos no código.

## Achados da terceira auditoria

| ID | Situação em 23/11/2026 |
|---|---|
| T-01 | **Corrigido** na branch `fix/t-01-cancelamento-dados-velhos`: as saídas por tempo só cancelam com `system/matchSync.lastSeasonSuccessAt` posterior ao prazo |
| T-02 | **Corrigido no app** (branch `fix/t-05-t-02-app-amigos`): segue `nextCursor`. A ordenação por `createdAt` sugerida na auditoria não foi feita no backend; a callable continua ordenando por `requesterId` |
| T-05 | **Parcial** (mesma branch): nomes recarregados e lembrados durante a sessão, "Jogador" para desconhecidos. Um ex-amigo nunca visto continua sem nome até existir consulta pública por UID no backend |
| T-03, T-04, T-06 a T-18 | **Abertos**, fora desta rodada por decisão do responsável; não foram reconferidos |

## Decisões de desenho que merecem revisão

- **Guarda `accountDeletions/{uid}`:** a exclusão de conta mantém, depois de concluída, um documento só com o UID no ID e um contador de janela, sem dado pessoal. Ele impede recriar o perfil e operar com um token ainda válido durante a limpeza, e preserva o limite de 3 tentativas por hora. As operações de amizade, reserva, criação e aceite de desafio, criação de perfil e busca consultam essa guarda.
- **`createChallenge` e remoção de amizade:** a criação de desafio passou a atualizar `updatedAt` do documento da amizade na mesma transação, para serializar com `removeFriend`.
- **Estado `REMOVED` da amizade:** preserva o histórico de cotas de reabertura; reenviar a solicitação exige novo aceite.
- **Ledger e desafios encerrados** permanecem após a exclusão de conta, só com UID.

## Pendências do responsável

- **Deploys:** índices (`firestore:indexes`) e as Functions alteradas ou novas; ver `docs/callable-functions.md` §9 e os relatórios de cada branch.
- **Jornada em dispositivo:** rodar os emuladores e os `integration_test/`.
- **Exclusão de conta real:** criar e excluir uma conta descartável no app para comprovar o Authentication, o retorno ao Login e a limpeza do cache.
- **Keystore de release** e `android/key.properties` (README, "Build de release").
- **Jira, links da entrega, push, merge e PRs.**

## Itens fora do escopo, só registrados

| Item | Estado |
|---|---|
| `LICENSE` | Não incluída (direitos do projeto acadêmico); decisão da equipe |
| App Check | `ENFORCE_APP_CHECK=false`; ligar exige registrar o app com Play Integrity |
| Crashlytics | Inexistente; só log em debug |
| Backup do Firestore | Backup pontual desligado em 01/11/2026; não reverificado |
| Índices no projeto | 12 declarados antes da rodada; estado "ativo" não conferido |
| Achados T-03, T-04, T-06 a T-18 | Abertos |
| Escudos de partidas já finalizadas | Não são preenchidos pela sincronização (regra anti-regressão) |
| Login por username | Devolve o e-mail da conta a quem souber o username |
