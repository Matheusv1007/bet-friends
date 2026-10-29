# Segunda Entrega — Protótipo funcional, integração de API e Status Report

**Prazo:** 05/11/2026, 21h · **Task:** KAN-104 · **Responsável:** Pedro Simon · **Atualizado em:** 29/10/2026 (`qas` em `5ed4796`, após os PRs #15 a #35)

Material de preparação da Segunda Entrega. Cada documento separa o que foi **executado e verificado** do que ainda **depende de ação manual** da equipe.

| Documento | Conteúdo |
|---|---|
| [checklist.md](checklist.md) | Critérios oficiais da entrega × estado atual |
| [validacao-tecnica.md](validacao-tecnica.md) | Resultados dos testes, da análise, do build e do ensaio no emulador |
| [funcionalidades.md](funcionalidades.md) | O que funciona no app real, o que só funciona nos emuladores, o que é demonstrativo e o que falta |
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
| Situação | Quase pronta: faltam ações de gestão (links, Jira, `main`) e o ensaio | Em construção: o backend avançou, mas nada além de login e partidas chegou ao app real |
| Avanço | — | ≈ 35 % do MVP implementado e testado em código; ≈ 12 % utilizável no app real (estimativa por módulo de 29/10) |
| Maior bloqueio | Nenhum técnico | Deploy das Cloud Functions e das Security Rules (plano Blaze); desafios (KAN-62) ainda não iniciados |

**Não apresentar como funcionalidades do app** o cadastro, as operações com BetCoins nem os desafios: existem só no código e nos emuladores, ou só como interface demonstrativa.
