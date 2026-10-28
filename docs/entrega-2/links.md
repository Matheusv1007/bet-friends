# Links da entrega (Classroom)

| Item | Link | Verificação em 28/10/2026 | Pendência |
|---|---|---|---|
| Repositório GitHub | https://github.com/Matheusv1007/bet-friends | ✅ Público e acessível (`gh api`) | ⚠️ A branch padrão `main` ainda contém o **template inicial do Flutter**, 29 commits atrás de `qas`. Quem abrir o link não verá o app atual |
| Branch com o código atual | https://github.com/Matheusv1007/bet-friends/tree/qas | ✅ `qas` contém os PRs #1 a #14 | Se `main` não for atualizada, citar este link explicitamente |
| Quadro Jira (projeto KAN) | _a preencher_ | ❌ Não verificado: o link não consta em nenhum documento do repositório | Copiar o link do quadro, conferir se está acessível ao professor e revisar o quadro |
| Slides ou vídeo (opcional) | _a preencher_ | — | Gravar o vídeo de contingência |

## Decisão pendente da equipe: atualizar `main`

Promover `qas → main` **não foi feito** nesta task. Antes, a equipe precisa decidir:

1. **Fazer ou não a promoção antes da entrega.** Alternativa: entregar o link da branch `qas`.
2. **Momento em relação à correção de segurança.** O token da football-data.org já está no histórico público do repositório desde setembro, em todas as branches, e a promoção não muda essa exposição. Ainda assim, recomenda-se tratar a KAN-102 (trocar o token) o quanto antes, independentemente da promoção.
3. **Como fazer.** Por Pull Request `qas → main` revisado pela equipe, sem push direto.

## Checklist do quadro Jira (manual)

- [ ] Concluídas (Done) coerentes com o código: KAN-26, KAN-27, KAN-99, KAN-100, KAN-101 (verificar critérios), além das já concluídas KAN-14, 15, 16, 19, 20, 23 e KAN-93 a KAN-96.
- [ ] KAN-32 em andamento, **não** concluída: a persistência real depende das regras do Firestore.
- [ ] "Em andamento" refletindo o trabalho real de cada integrante.
- [ ] Backlog com o que falta para a Entrega 3.
- [ ] Link com permissão de visualização para o professor.
