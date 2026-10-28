# Checklist da Segunda Entrega — 05/11/2026, 21h

Legenda: ✅ atendido e verificado · 🟡 atendido com ressalvas · ⏳ pendente (ação manual) · ❌ não atendido

## 1. Protótipo funcional

| Critério | Estado | Evidência / pendência |
|---|---|---|
| App roda no emulador | ✅ | Build debug e `flutter run` em 28/10; roteiro completo (passos 0–9) executado sem crash ([validacao-tecnica.md](validacao-tecnica.md)) |
| Telas principais criadas | 🟡 | Login, Cadastro (visual), Home, Criar Desafio. Perfil, Amigos e Créditos ainda não existem |
| Navegação sem crash | ✅ | Login, Cadastro, Home, Criar Desafio, logout e sessão restaurada verificados em 28/10; sem erros no log. Abas Ranking e Perfil não abrem tela (não quebram) |
| UI utilizável | ✅ | Ver [funcionalidades.md](funcionalidades.md) |
| Integração inicial com a API | ✅ | `ApiClient` → `PartidasService` → `PartidasProvider`; partidas reais exibidas no ensaio de 28/10 |

## 2. Gestão e repositório

| Critério | Estado | Evidência / pendência |
|---|---|---|
| Código versionado no GitHub | 🟡 | Repositório público com 14 PRs; **`main` desatualizada** (ver [links.md](links.md)) |
| README útil | ✅ | Atualizado nesta task (falta commit) |
| Quadro Jira atualizado | ⏳ | Revisão manual; link não registrado |
| Divisão de tarefas visível | 🟡 | Commits e PRs de 4 integrantes no histórico; trabalho recente concentrado em um integrante |

## 3. Status Report (≤ 5 min)

| Item | Estado |
|---|---|
| Roteiro escrito | ✅ [status-report.md](status-report.md) |
| Roteiro da demo | ✅ [roteiro-demonstracao.md](roteiro-demonstracao.md) |
| Ensaio cronometrado | ⏳ |
| Vídeo de contingência | ⏳ |
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

1. ~~Executar o roteiro completo no emulador~~ (✅ 28/10). Falta ensaiar **falado** e cronometrar.
2. Gravar o vídeo de contingência.
3. Decidir sobre `qas → main` (PR) e registrar o link correto.
4. Revisar o Jira e copiar o link.
5. Commit e PR desta task (README e `docs/entrega-2/`).
