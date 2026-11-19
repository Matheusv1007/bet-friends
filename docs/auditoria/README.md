# Auditoria Técnica do BetFriends

> **Segunda auditoria (2026-11-19):** novos achados N-01 a N-30 em [segunda-auditoria.md](segunda-auditoria.md). Este documento descreve a primeira auditoria (A-01 a A-13), já corrigida.

| Campo | Valor |
|---|---|
| Data | 2026-11-19 |
| Escopo | App Flutter (`lib/`), backend (`functions/`), regras e índices do Firestore, configuração Android, testes e higiene do repositório |
| Método | Leitura de código, `flutter analyze`, `flutter test` e `npm test` em `functions/` |
| Documento detalhado | [achados.md](achados.md) |

## Resultado das verificações automáticas

| Verificação | Resultado |
|---|---|
| `flutter analyze` | 6 infos, todas `file_names` (arquivos em camelCase) |
| `flutter test` | 327 testes passaram |
| `npm test` (`functions/`) | 181 testes passaram |
| Testes de regras do Firestore (`tests/firestore-rules`) | Não executados (exigem emulador) |
| Testes `*.emulator.test.ts` e `integration_test/` | Não executados (exigem emulador/dispositivo) |

Achados marcados como **[INFERÊNCIA]** vêm de leitura de código e não foram confirmados em execução.

## Pontos fortes

- Operações com saldo e mudanças de estado acontecem somente no backend (Admin SDK). `firestore.rules` bloqueia escrita do cliente, exceto `displayName`.
- Reserva, liquidação e expiração são transacionais e idempotentes. O ledger de BetCoins é imutável.
- O token da Football-Data fica no Secret Manager. Não há credencial externa em `lib/`.
- A ferramenta `functions/src/dev/reposicao.ts` só roda em projeto `demo-*` com emulador local, fora do deploy.
- Cobertura de testes ampla, tanto no app quanto no backend.

## Resumo dos achados

| ID | Severidade | Título | Área |
|---|---|---|---|
| A-01 | Alta | Fundos reservados podem ficar presos (falta `REJEITAR`/`CANCELAR`) | Backend / negócio |
| A-02 | Alta | `getMatchesRest` público, sem App Check e sem limite de uso | Backend / segurança |
| A-03 | Alta | Índices compostos ausentes (`matches`, `friendships`) | Firestore |
| A-04 | Média | Release Android assinado com chave de debug | Android |
| A-05 | Média | Sem App Check; `searchUsers` permite varredura | Backend / segurança |
| A-06 | Média | Job `syncMatches` varre desafios em série (risco de timeout) | Backend / escala |
| A-07 | Média | `catch (_)` genéricos engolem erros no cliente | Flutter |
| A-08 | Baixa | Artefatos versionados (`problems-report.html`) e chave sem restrição documentada | Repositório |
| A-09 | Baixa | Aliases de payload e tabela de erros duplicada nas callables de desafio | Backend |
| A-10 | Baixa | Código morto/legado no app (`ApiClient`, `apiKey`, `App` comentado) | Flutter |
| A-11 | Baixa | Arquivos grandes e nomes fora do padrão Dart | Flutter |
| A-12 | Baixa | Sem CI | Repositório |
| A-13 | Baixa | Documentos soltos na raiz (`AnaliseTemporaria.md`) | Repositório |

## Status de correção

Atualizar a coluna **Status** em [achados.md](achados.md) conforme cada item for resolvido, citando o PR.
