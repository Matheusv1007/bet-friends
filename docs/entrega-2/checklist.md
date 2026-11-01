# Checklist da Segunda Entrega — 05/11/2026, 21h

Atualizado em 01/11/2026 (base: `qas` em `805eea8`).

Legenda: ✅ atendido e verificado · 🟡 atendido com ressalvas · ⏳ pendente (ação manual) · ❌ não atendido

## 1. Protótipo funcional

| Critério | Estado | Evidência / pendência |
|---|---|---|
| App roda no emulador | ✅ | App atual executado no `emulator-5554` contra o Firebase real em 01/11 ([validacao-tecnica.md](validacao-tecnica.md)) |
| Telas principais criadas | 🟡 | Login, Cadastro, Home, Perfil e Criar Desafio (demonstrativa); Amigos e Créditos ainda não existem |
| Navegação sem crash | 🟡 | Login, Cadastro, Home, Perfil e logout sem crash em 01/11; "Mais partidas" e Criar Desafio não foram refeitos desde 28/10 (reensaio pendente) |
| UI utilizável | ✅ | Ver [funcionalidades.md](funcionalidades.md) |
| Integração inicial com a API | ✅ | Partidas reais na Home em 01/11. Ressalva: o app chama a API diretamente, com o token no cliente |

## 2. Gestão e repositório

| Critério | Estado | Evidência / pendência |
|---|---|---|
| Código versionado no GitHub | 🟡 | PRs até o #56 integrados à `qas`; **`main` estava 115 commits atrás em 01/11** (ver [links.md](links.md)) |
| README útil | ✅ | Atualizado em 01/11 nesta task (falta commit) |
| Quadro Jira atualizado | ⏳ | Atualização coordenada separadamente; link não registrado |
| Divisão de tarefas visível | 🟡 | Commits e PRs dos 4 integrantes no histórico, com concentração em parte dos integrantes; alguns PRs sem descrição ou revisão formal registrada |

## 3. Status Report (≤ 5 min)

| Item | Estado |
|---|---|
| Roteiro escrito | ✅ [status-report.md](status-report.md) (atualizado em 01/11) |
| Roteiro da demo | ✅ [roteiro-demonstracao.md](roteiro-demonstracao.md) (atualizado em 01/11) |
| Reensaio completo da demo no app atual | ⏳ |
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
- [ ] Não digitar senhas com a tela visível, não usar o ícone de olho e não colar senha: a área de transferência do computador aparece no teclado do emulador.
- [ ] Não usar a conta de teste B.

## Ações manuais, por prioridade

1. Revisar, fazer o commit e abrir o PR desta task (README e `docs/entrega-2/`).
2. Decidir com a equipe a branch entregue e registrar o link correto.
3. Atualizar o Jira e copiar o link.
4. Reinstalar o app e refazer o roteiro completo da demo.
5. Ensaiar falado e cronometrar.
6. Gravar o vídeo de contingência.
7. Enviar no Classroom até 05/11, às 21h.
