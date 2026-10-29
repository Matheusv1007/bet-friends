# Links da entrega (Classroom)

| Item | Link | Verificação | Pendência |
|---|---|---|---|
| Repositório GitHub | https://github.com/Matheusv1007/bet-friends | ✅ Público e acessível (28/10, `gh api`) | ⚠️ A branch padrão `main` ainda contém o **template inicial do Flutter**, 72 commits atrás de `qas` (29/10). Quem abrir o link não verá o app atual |
| Branch com o código atual | https://github.com/Matheusv1007/bet-friends/tree/qas | ✅ `qas` em `5ed4796`, com os PRs #1 a #35 (29/10) | Se `main` não for atualizada, citar este link explicitamente |
| Quadro Jira (projeto KAN) | _a preencher_ | ❌ Não verificado: o link não consta em nenhum documento do repositório | Copiar o link do quadro, conferir se está acessível ao professor e revisar o quadro |
| Slides ou vídeo (opcional) | _a preencher_ | — | Gravar o vídeo de contingência |

## Decisão pendente da equipe: atualizar `main`

Promover `qas → main` **não foi feito**. Antes, a equipe precisa decidir:

1. **Fazer ou não a promoção antes da entrega.** Alternativa: entregar o link da branch `qas`.
2. **Momento em relação à correção de segurança.** O token da football-data.org já está no histórico público do repositório desde setembro, em todas as branches, e a promoção não muda essa exposição. Ainda assim, recomenda-se tratar a KAN-102 (trocar o token) o quanto antes. O token novo não deve voltar ao código do app.
3. **Como fazer.** Por Pull Request `qas → main` revisado pela equipe, sem push direto.

## Checklist do quadro Jira (manual)

Usar "concluída" só para o que funciona no produto. O que está implementado e testado apenas nos emuladores deve ficar em revisão/QA, ou com a nota "sem deploy".

- [ ] Concluídas (Done) coerentes com o código e o app real: KAN-26, KAN-27, KAN-99, KAN-100, KAN-101 (verificar critérios), além das já concluídas KAN-14, 15, 16, 19, 20, 23 e KAN-93 a KAN-96.
- [ ] Implementadas sem deploy (revisão/QA, **não** Done): KAN-18, 22, 28, 29, 31, 32, 46, 47, 48, 72, 73, 74, 75, 76, 77, 78, 79.
- [ ] Parciais (em andamento): KAN-21 (segredo sem uso), KAN-24, KAN-25 (só o backend existe).
- [ ] KAN-31: implementada por Matheus Vasco; atualizar o responsável, se ainda estiver com outro integrante.
- [ ] KAN-75: entrou pelo PR #30, sem PR próprio; registrar no card.
- [ ] KAN-104 em andamento até o envio no Classroom.
- [ ] "Em andamento" refletindo o trabalho real de cada integrante.
- [ ] Backlog com o que falta para a Entrega 3.
- [ ] Link com permissão de visualização para o professor.
