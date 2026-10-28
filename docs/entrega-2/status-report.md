# Status Report — roteiro de até 5 minutos

> Rascunho para a equipe revisar. Ajuste nomes, divisão de falas e números antes da apresentação. Tempo estimado por leitura em voz alta; **ainda não cronometrado em ensaio**.

## 1. Abertura (≈ 20 s)

"O BetFriends é um app Android para desafios 1x1 entre amigos sobre partidas reais do Brasileirão, usando BetCoins, uma moeda fictícia. Nesta entrega mostramos o protótipo rodando, a integração com a API de futebol e o andamento do projeto."

## 2. O que foi feito (≈ 2 min 30 s, com a demo)

Seguir o [roteiro de demonstração](roteiro-demonstracao.md). Pontos a destacar:

- **Autenticação real** com Firebase: login, sessão restaurada e logout seguro.
- **Integração com a API football-data.org v4:** partidas reais do Brasileirão com estados de carregamento, erro e vazio, atualização automática e preservação dos dados quando a rede falha.
- **Navegação:** Login, Cadastro, Home e Criar Desafio, sem crash.
- **Base do backend:** Firestore configurado, estrutura de Callable Functions com autenticação e validação, e modelo de perfil vinculado ao UID.
- **Qualidade:** 65 testes automatizados no app e 7 no backend; trabalho organizado em branches por task e Pull Requests revisados para a branch `qas`.

Ser transparente: cadastro, saldo, amigos e envio de desafio ainda são demonstrativos.

## 3. Desafios técnicos (≈ 1 min)

Escolher **um** como principal e citar os outros brevemente:

1. **Segurança da API de futebol:** o token não pode ficar no app. A arquitetura correta coloca as chamadas no backend (Cloud Functions + Firestore como cache), mas isso exige habilitar as Cloud Functions no plano pago do Firebase (Blaze).
2. **Limite da API gratuita** (10 chamadas por minuto): obrigou a pensar em cache e em sincronização centralizada, em vez de cada celular consultar a API.
3. **Integridade das BetCoins:** reservas e premiações precisam ser atômicas e feitas no servidor, para evitar saldo negativo ou duplicado. Por isso o desenho do banco foi priorizado antes das telas.
4. **Ambiente e build Android:** permissão de Internet no build release, emulador no Linux e versões de plugins.

## 4. Próximos passos para a Entrega 3 (≈ 1 min)

1. Mover a API de futebol para o backend e trocar o token (KAN-21, KAN-102, KAN-44 a KAN-50).
2. Consolidar o banco e as regras de segurança (KAN-103, KAN-22).
3. Cadastro real com perfil e username único, carteira com 1.000 BetCoins (KAN-25, KAN-31, KAN-32, KAN-72).
4. Amizades e desafios com palpites, reserva de saldo e estados (KAN-33 a KAN-41, KAN-55 a KAN-68).
5. Liquidação automática pelo resultado oficial, extrato e histórico (KAN-82 a KAN-91).
6. Tela de créditos da fonte de dados (KAN-54).

## 5. Encerramento (≈ 10 s)

"O fluxo completo de um desafio, da criação à liquidação, é o objetivo da Entrega 3. Obrigado."

## Divisão sugerida de falas (a confirmar pela equipe)

| Parte | Sugestão |
|---|---|
| Abertura e demo | Pedro Simon (autenticação) e Kauê Pimenta (partidas e telas) |
| Desafios técnicos | Matheus Vasco (backend e API) |
| Próximos passos | Guilherme Silva (desafios e regras) |
