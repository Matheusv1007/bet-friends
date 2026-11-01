# Segunda Entrega — Protótipo funcional, integração de API e Status Report

**Prazo:** 05/11/2026, 21h · **Task:** KAN-104 · **Responsável:** Pedro Simon · **Atualizado em:** 01/11/2026 (base: `qas` em `805eea8`)

> **Situação em 01/11/2026:** o projeto real está no plano Blaze, com as Security Rules e quatro Cloud Functions publicadas. Cadastro, perfil, carteira inicial e comportamento offline foram validados no app Android contra o Firebase real. Amizades e desafios reais continuam fora do app. Detalhes em [validacao-tecnica.md](validacao-tecnica.md).

Material de preparação da Segunda Entrega. Cada documento separa o que foi **executado e verificado** do que ainda **depende de ação manual** da equipe.

| Documento | Conteúdo |
|---|---|
| [checklist.md](checklist.md) | Critérios oficiais da entrega × estado atual |
| [validacao-tecnica.md](validacao-tecnica.md) | Testes automatizados, validação no Firebase real e histórico de ensaios |
| [funcionalidades.md](funcionalidades.md) | O que funciona no app real, o que só foi testado em emulador, o que é demonstrativo e o que falta |
| [roteiro-demonstracao.md](roteiro-demonstracao.md) | Roteiro passo a passo da demo, com plano de contingência |
| [status-report.md](status-report.md) | Roteiro falado de até 5 minutos: o que foi feito, dificuldades e próximos passos |
| [links.md](links.md) | Links do repositório e do Jira a anexar no Classroom, com verificação |

## O que o professor espera (resumo das instruções)

1. **Protótipo funcional:** app rodando em emulador ou aparelho, telas principais navegáveis, UI utilizável, integração inicial com a API.
2. **Gestão e repositório:** código versionado no GitHub; quadro Jira "vivo", com Done, Doing e Backlog.
3. **Status Report (máx. 5 min):** o que foi feito, maior dificuldade técnica e próximos passos para a Entrega 3.
4. **Anexar no Classroom:** link do repositório, link do Jira e, opcionalmente, slides ou vídeo.

Critérios de avaliação: progresso do MVP, telas que compilam e navegam sem crash, arquitetura de consumo da API configurada e gestão do trabalho (Jira atualizado e divisão de tarefas no repositório).

## Segunda Entrega × MVP final

A Segunda Entrega pede um **protótipo** navegável com integração inicial da API; o MVP final (Entrega 3) exige o fluxo completo: cadastrar → fazer amizade → desafiar → liquidar → consultar o histórico.

| | Segunda Entrega (05/11) | MVP final |
|---|---|---|
| Situação | Base técnica validada; faltam reensaio da demo, ações de gestão (links, Jira, branch entregue) e vídeo de contingência | Em construção: conta, perfil e carteira inicial funcionam no produto; desafios ainda não |
| Maior bloqueio | Nenhum técnico | Callables de desafio, início de partida (KAN-66), amizades e app lendo `matches` |

**Não apresentar como funcionalidades do app:** saldo na interface, amizades, envio de desafio e bônus de recuperação. Existem só no backend ou como interface demonstrativa.

## Ressalvas que devem continuar visíveis

- **Token da Football-Data:** o app ainda chama a API diretamente, com o token no cliente. Não distribua APKs.
- **Negação de escrita pelo cliente:** comprovada só no Firestore Emulator, com as mesmas regras publicadas. A execução em produção não foi autorizada.
- **Cadastro:** a mensagem de e-mail repetido revela que o e-mail existe, e um username recusado deixa a conta no Auth sem perfil, a ser concluída depois.
- **Recuperação de BetCoins:** publicada, mas sem tela e sem execução em produção.
- **Conta de teste B:** a senha digitada foi exposta durante a preparação de um teste, então não deve ser usada na demonstração.
