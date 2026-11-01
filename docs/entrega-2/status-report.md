# Status Report — roteiro de até 5 minutos

> Rascunho para a equipe revisar, atualizado em 01/11/2026. Ajuste nomes e divisão de falas antes da apresentação. Tempo estimado por leitura em voz alta; **ainda não cronometrado em ensaio**.

## 1. Abertura (≈ 20 s)

"O BetFriends é um app Android para desafios 1x1 entre amigos sobre partidas reais do Brasileirão, usando BetCoins, uma moeda fictícia. Nesta entrega mostramos o protótipo rodando, a integração com a API de futebol e a base de conta, perfil e carteira funcionando no Firebase real."

## 2. O que foi feito (≈ 2 min 30 s, com a demo)

Seguir o [roteiro de demonstração](roteiro-demonstracao.md). Pontos a destacar:

- **Conta real:** cadastro, login e logout com Firebase. O cadastro cria perfil, username único e carteira de 1.000 BetCoins numa única transação, com bloqueio de dados inválidos ou repetidos.
- **Perfil:** ligado ao UID, com edição do nome que persiste depois de novo login.
- **Sem conexão:** o app mostra os dados salvos e bloqueia alterações, sem falsa confirmação nem escrita pendente.
- **Integração com a API football-data.org v4:** partidas reais na Home, com estados de carregamento, erro e vazio e atualização automática.
- **Backend publicado:** Security Rules e quatro Cloud Functions no projeto real, incluindo a `syncMatches`, que grava as partidas no Firestore a cada 5 minutos.
- **Validação real:** testes controlados no Firebase real, com contas de teste, cobrindo erros, falta de rede e chamadas simultâneas sem duplicar a carteira.
- **Qualidade:** 176 testes no app, 118 testes puros do backend, 365 em emulador (backend e regras) e 54 de integração no Android. Trabalho em branches por task e Pull Requests para a `qas`.

Ser transparente: saldo na tela, amigos e envio de desafio ainda são demonstrativos ou inexistentes. Os módulos de reserva, liquidação e recuperação existem no backend, mas ainda não têm fluxo real no app.

## 3. Desafios técnicos (≈ 1 min)

Escolher **um** como principal e citar os outros brevemente:

1. **Validar em produção com segurança (sugerido como principal):** testar um app com carteira no Firebase real sem corromper dados. Fizemos os testes por etapas, conferindo contagens, saldos e logs antes e depois. Uma das escolhas foi não executar tentativas reais de gravação indevida em produção, porque o banco não tem backup. Essas negações seguem comprovadas no emulador, com as mesmas regras publicadas, e isso fica registrado como limitação.
2. **Segurança da API de futebol:** o backend já usa o token como segredo, mas o app ainda chama a API com um token no cliente. Só depois de o app ler do Firestore será possível trocar o token e distribuir o APK.
3. **Integridade das BetCoins:** cada movimentação grava saldo e lançamento na mesma transação, e repetir uma operação não a aplica duas vezes.
4. **Limite da API gratuita** (10 chamadas por minuto): levou à sincronização centralizada, em vez de cada celular consultar a API.

## 4. Próximos passos para a Entrega 3 (≈ 1 min)

1. Callables e telas de criar, aceitar e recusar desafio, com reserva de saldo (KAN-55 a KAN-68).
2. Amizades (KAN-33 a KAN-41).
3. Saldo e extrato na interface e tela do bônus de recuperação (KAN-69 a KAN-71).
4. App lendo `matches` e troca do token (KAN-42, KAN-102).
5. Medição do atraso real da API gratuita (KAN-53), decisão sobre a conferência do resultado antes de liquidar em produção, e histórico (KAN-89).
6. Backup do banco, alertas de custo e tela de créditos da fonte de dados (KAN-54).

## 5. Encerramento (≈ 10 s)

"A base de conta, perfil e carteira já funciona no produto. O fluxo completo de um desafio, da criação à liquidação, é o objetivo da Entrega 3. Obrigado."

## Divisão sugerida de falas (a confirmar pela equipe)

| Parte | Sugestão |
|---|---|
| Abertura e demo | Pedro Simon (conta e perfil) e Kauê Pimenta (partidas e telas) |
| Desafios técnicos | Pedro Simon (validação) e Matheus Vasco (backend, BetCoins e API) |
| Próximos passos | Guilherme Silva (desafios e regras) |
