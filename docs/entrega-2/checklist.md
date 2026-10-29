# Checklist da Segunda Entrega — 05/11/2026, 21h

Atualizado em 29/10/2026 (`qas` em `5ed4796`).

Legenda: ✅ atendido e verificado · 🟡 atendido com ressalvas · ⏳ pendente (ação manual) · ❌ não atendido

## 1. Protótipo funcional

| Critério | Estado | Evidência / pendência |
|---|---|---|
| App roda no emulador | 🟡 | Build debug e roteiro completo sem crash em 28/10, **com o código do PR #14**. Depois disso entraram Perfil, edição de nome, modo offline e a limpeza da Home (PRs #19 a #25), cobertos por 128 testes de widget e 33 de integração, mas **o roteiro completo não foi refeito no app atual** ([validacao-tecnica.md](validacao-tecnica.md)) |
| Telas principais criadas | 🟡 | Login, Cadastro (visual), Home, Criar Desafio e Perfil. A tela de Perfil só foi validada nos emuladores do Firebase; Amigos e Créditos ainda não existem |
| Navegação sem crash | 🟡 | Verificada em 28/10 no código anterior. Barra atual: Home, Desafios e Perfil (Ranking removido por ser pós-MVP), coberta por `test/home_mvp_test.dart`. Reensaio no emulador pendente |
| UI utilizável | ✅ | Ver [funcionalidades.md](funcionalidades.md) |
| Integração inicial com a API | ✅ | `ApiClient` → `PartidasService` → `PartidasProvider`; partidas reais exibidas no ensaio de 28/10. Ressalva: o app chama a API diretamente, com o token no cliente |

## 2. Gestão e repositório

| Critério | Estado | Evidência / pendência |
|---|---|---|
| Código versionado no GitHub | 🟡 | 35 PRs integrados à `qas`; **`main` ainda é o template, 72 commits atrás** (ver [links.md](links.md)) |
| README útil | ✅ | Atualizado em 29/10 nesta task (falta commit) |
| Quadro Jira atualizado | ⏳ | Revisão manual; link não registrado. Ver as recomendações de status em [links.md](links.md) |
| Divisão de tarefas visível | 🟡 | Commits e PRs dos 4 integrantes no histórico, mas a maior parte dos PRs recentes é de dois integrantes. Os PRs #26 a #35 foram integrados **sem descrição nem revisão formal registrada** |

## 3. Status Report (≤ 5 min)

| Item | Estado |
|---|---|
| Roteiro escrito | ✅ [status-report.md](status-report.md) (atualizado em 29/10) |
| Roteiro da demo | ✅ [roteiro-demonstracao.md](roteiro-demonstracao.md) (atualizado em 29/10) |
| Reensaio da demo no app atual | ⏳ |
| Ensaio falado e cronometrado | ⏳ |
| Vídeo de contingência | ⏳ (gravar entre 03 e 05/11) |
| Slides (opcional) | ⏳ (decisão da equipe) |

## 4. Anexos no Classroom

- [ ] Link do repositório (decidir entre `main` atualizada e o link da `qas`).
- [ ] Link do Jira.
- [ ] (Opcional) Vídeo ou slides.

## 5. Segurança antes de apresentar

- [ ] Não exibir nem anexar o APK.
- [ ] Não mostrar `lib/services/api/partidas_service.dart` na tela compartilhada.
- [ ] Não digitar a senha da conta de demonstração com a tela visível.

## Ações manuais, por prioridade

1. Decidir com a equipe sobre `qas → main` (por PR revisado) e registrar o link correto.
2. Revisar o Jira (status coerentes com "implementado, sem deploy") e copiar o link.
3. Refazer o roteiro da demo no app atual, incluindo a aba Perfil no Firebase real, para decidir se ela entra na apresentação.
4. Ensaiar falado e cronometrar.
5. Gravar o vídeo de contingência.
6. Commit e PR desta task (README e `docs/entrega-2/`).
