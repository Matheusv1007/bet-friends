# Links da entrega (Classroom)

| Item | Link | Verificação | Pendência |
|---|---|---|---|
| Repositório GitHub | https://github.com/Matheusv1007/bet-friends | ✅ Público e acessível (última conferência em 28/10, `gh api`) | ⚠️ A branch padrão `main` estava 115 commits atrás de `qas` em 01/11. Quem abrir o link não verá o app atual |
| Branch com o código atual | https://github.com/Matheusv1007/bet-friends/tree/qas | ✅ `qas` em `805eea8` (01/11), com os PRs até o #56 | Conferir o commit final depois do PR desta task. Se `main` não for atualizada, citar este link explicitamente |
| Quadro Jira (projeto KAN) | _a preencher_ | ❌ O link não consta em nenhum documento do repositório | Copiar o link do quadro, conferir se está acessível ao professor e revisar o quadro |
| Slides ou vídeo (opcional) | _a preencher_ | — | Gravar o vídeo de contingência |

## Decisão pendente da equipe: atualizar `main`

Promover `qas → main` **não foi feito**. Antes, a equipe precisa decidir:

1. **Fazer ou não a promoção antes da entrega.** Alternativa recomendada, por menor risco às vésperas do prazo: entregar o link da branch `qas`.
2. **Momento em relação à correção de segurança.** O token da football-data.org já está no histórico público do repositório desde setembro, em todas as branches, e a promoção não muda essa exposição. Ainda assim, a KAN-102 (trocar o token) deve ser tratada o quanto antes, depois de o app ler `matches`. O token novo não deve voltar ao código do app.
3. **Como fazer.** Por Pull Request `qas → main` revisado pela equipe, sem push direto.

## Evidências para o quadro Jira (atualização manual)

Este documento não reflete o status do quadro. Ele resume as evidências para a equipe usar ao atualizá-lo. Detalhes em [validacao-tecnica.md](validacao-tecnica.md).

| Task | Evidência | Ressalva a registrar |
|---|---|---|
| KAN-25 Criar conta | Firebase real: cadastro válido, username e e-mail repetidos, senha, falha de rede e conclusão na mesma tela | Retomada pelo Perfil só em emulador; mensagem revela e-mail existente |
| KAN-32 Perfil por UID | Firebase real: perfil por UID, leitura pelo dono, edição, persistência, bloqueio de leitura de terceiros e listagem | Negação de escrita só em emulador |
| KAN-72 Carteira inicial | Firebase real: 1.000 BetCoins, lançamento único por perfil e 5 chamadas simultâneas sem duplicar | Negação de escrita e disputa na primeira criação só em emulador |
| KAN-24 Offline | Firebase real: aviso e dados salvos, edição bloqueada, cadastro offline sem gravação | Vale para as escritas atuais; novas features devem seguir a regra |
| KAN-28, KAN-29 | Firebase real: tela de Perfil e edição do nome com persistência | — |
| KAN-80 Recuperação | Testes em emulador; função publicada | Sem tela e sem execução em produção; depende de decisão da equipe |
| KAN-104 | Este material | Em andamento até o envio no Classroom |

Conferir ainda:

- [ ] "Em andamento" refletindo o trabalho real de cada integrante.
- [ ] Backlog com o que falta para a Entrega 3.
- [ ] Link com permissão de visualização para o professor.
