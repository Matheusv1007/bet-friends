# Status Report — roteiro de até 5 minutos

> Rascunho para a equipe revisar, atualizado em 29/10/2026. Ajuste nomes, divisão de falas e números antes da apresentação. Tempo estimado por leitura em voz alta; **ainda não cronometrado em ensaio**.

## 1. Abertura (≈ 20 s)

"O BetFriends é um app Android para desafios 1x1 entre amigos sobre partidas reais do Brasileirão, usando BetCoins, uma moeda fictícia. Nesta entrega mostramos o protótipo rodando, a integração com a API de futebol e o andamento do backend."

## 2. O que foi feito (≈ 2 min 30 s, com a demo)

Seguir o [roteiro de demonstração](roteiro-demonstracao.md). Pontos a destacar:

- **Autenticação real** com Firebase: login, sessão restaurada e logout seguro.
- **Integração com a API football-data.org v4:** partidas reais do Brasileirão com estados de carregamento, erro e vazio, atualização automática e preservação dos dados quando a rede falha.
- **Navegação:** Login, Cadastro, Home, Criar Desafio e Perfil, sem crash. O Ranking saiu da navegação por estar fora do escopo do MVP.
- **Banco e segurança:** schema do Firestore documentado e Security Rules por coleção, com 77 testes no emulador e publicadas no projeto real em 29/10.
- **Backend (Cloud Functions), testado no emulador e ainda sem deploy:** cadastro com username único e carteira inicial de 1.000 BetCoins numa só transação; registro auditável de cada movimentação; reserva, liberação, premiação, perda e reembolso de BetCoins, inclusive com operações simultâneas; e modelo interno das partidas com status e resultado.
- **Perfil:** tela de perfil e edição do nome, validadas no Android contra os emuladores do Firebase.
- **Qualidade:** 128 testes no app, 131 no backend, 77 das regras e 33 de integração no Android (última execução em 28/10). Trabalho organizado em branches por task e Pull Requests para a branch `qas`.

Ser transparente: cadastro pela tela, saldo, amigos e envio de desafio ainda são demonstrativos. O backend existe, mas ainda não está implantado nem ligado às telas.

## 3. Desafios técnicos (≈ 1 min)

Escolher **um** como principal e citar os outros brevemente:

1. **Deploy do backend:** as Cloud Functions exigem o plano pago do Firebase (Blaze). Em 28/10 a Cloud Functions API ainda estava desabilitada. Em 29/10 as Security Rules foram publicadas (não exigem o Blaze), mas o projeto continua no plano gratuito, e o deploy das Functions também depende de uma permissão do dono do projeto. Por isso, todo o backend foi validado nos emuladores, e o app real ainda não usa cadastro nem BetCoins.
2. **Segurança da API de futebol:** o token não pode ficar no app. O backend já tem a estrutura para guardá-lo como segredo, mas as chamadas ainda precisam ser movidas para lá (Adapter e sincronização).
3. **Integridade das BetCoins:** reservas e premiações precisam ser atômicas e feitas no servidor, para evitar saldo negativo ou duplicado. Por isso cada movimentação grava o saldo e o lançamento na mesma transação, e repetir uma operação não a aplica duas vezes.
4. **Limite da API gratuita** (10 chamadas por minuto): obrigou a pensar em cache e em sincronização centralizada, em vez de cada celular consultar a API.

## 4. Próximos passos para a Entrega 3 (≈ 1 min)

1. Habilitar o plano Blaze, resolver a permissão de deploy e fazer o primeiro deploy das Cloud Functions (as Security Rules já foram publicadas em 29/10).
2. Cadastro real pela tela usando o backend, com perfil e carteira (KAN-25, KAN-32).
3. Mover a API de futebol para o backend e trocar o token (KAN-44, KAN-45, KAN-49, KAN-50, KAN-102).
4. Amizades e desafios com palpites, reserva de saldo e estados (KAN-33 a KAN-41, KAN-55 a KAN-68).
5. Liquidação automática pelo resultado oficial, extrato, bônus de recuperação e histórico (KAN-70, KAN-80, KAN-82 a KAN-91).
6. Tela de créditos da fonte de dados (KAN-54).

## 5. Encerramento (≈ 10 s)

"O fluxo completo de um desafio, da criação à liquidação, é o objetivo da Entrega 3. Obrigado."

## Divisão sugerida de falas (a confirmar pela equipe)

| Parte | Sugestão |
|---|---|
| Abertura e demo | Pedro Simon (autenticação e perfil) e Kauê Pimenta (partidas e telas) |
| Desafios técnicos | Matheus Vasco (backend, BetCoins e API) |
| Próximos passos | Guilherme Silva (desafios e regras) |
