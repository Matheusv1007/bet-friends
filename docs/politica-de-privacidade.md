# Política de Privacidade (rascunho)

> **Rascunho técnico, sem validação jurídica.** Descreve o que o BetFriends faz com os dados, conforme o código em 23/11/2026. A equipe deve revisá-lo antes de qualquer publicação. O BetFriends é um projeto acadêmico da disciplina de Desenvolvimento Mobile, sem fins comerciais; as BetCoins são uma moeda fictícia, sem valor em dinheiro.

## 1. Quais dados são tratados

| Dado | Origem | Onde fica | Quem vê |
|---|---|---|---|
| E-mail e senha | Cadastro | Firebase Authentication (a senha nunca chega ao banco do app) | Só o próprio usuário. O e-mail também fica em `users/{uid}`, que só o dono lê |
| Nome de exibição e username | Cadastro | `users/{uid}` e reserva em `usernames` | Outros usuários, ao buscar ou ao serem amigos: só nome e `@username` |
| Saldos de BetCoins (total, reservado) | Sistema | `users/{uid}` | Só o próprio usuário |
| Extrato (lançamentos de BetCoins) | Sistema | `betCoinTransactions` | Só o próprio usuário |
| Amizades e solicitações | Ações do usuário | `friendships` | Os dois participantes |
| Desafios, palpites e resultados | Ações do usuário | `challenges` | Os dois participantes |
| Contadores de uso (limites) | Sistema | `rateLimits` | Só o backend |
| Endereço IP, só no login por username | Rede | Aplicado como hash no contador de limite de `resolveLoginEmail` | Só o backend |

O app não coleta localização, contatos, câmera nem identificadores de publicidade. Não há Crashlytics nem análise de uso.

## 2. Para quê

- Criar a conta, autenticar e manter a sessão.
- Permitir buscar amigos, desafiar e liquidar desafios com o resultado oficial das partidas.
- Manter o extrato auditável (movimentação de BetCoins imutável).
- Limitar abuso (limites de uso por usuário).

## 3. Com quem os dados são processados

- **Google Firebase** (Authentication, Cloud Firestore e Cloud Functions), região `southamerica-east1` para banco e funções.
- **football-data.org** fornece as partidas e os resultados. O app só consulta o provedor por meio do backend, e nenhum dado de usuário é enviado a ele. Os escudos dos times são carregados da URL do provedor e pertencem aos respectivos clubes.

## 4. Visibilidade entre usuários

- A busca e as listas mostram só o nome de exibição e o `@username`.
- O login por username consulta o backend, que devolve o e-mail da conta a quem informar o username. Isso expõe o e-mail a quem souber o username (limite de 10 consultas por minuto por IP); a senha continua necessária para entrar.

## 5. Exclusão da conta

O Perfil permite excluir a própria conta, com reautenticação por senha. A exclusão é recusada enquanto houver desafio em andamento (`PENDING`, `ACCEPTED`, `IN_PROGRESS` ou `WAITING_RESULT`) ou saldo reservado.

**É apagado:** o perfil (`users/{uid}`, com e-mail, nome e saldos), a reserva do username (que volta a ficar livre), todas as amizades e solicitações do usuário, os contadores de limite de uso e a conta no Firebase Authentication.

**Permanece:**
- o extrato e os desafios já encerrados, que são registros financeiros imutáveis e guardam apenas o identificador interno (UID), sem nome, e-mail nem username; para o outro jogador, o ex-usuário deixa de ter nome associado;
- um marcador técnico `accountDeletions/{uid}` (identificador interno, data da janela e contador, sem dado pessoal), que impede recriar o perfil durante a limpeza e mantém o limite de tentativas.

Quem excluir a conta e quiser voltar precisa criar um cadastro novo, com 1.000 BetCoins iniciais.

## 6. Retenção e segurança

- Os dados ficam enquanto a conta existir. Depois da exclusão, só permanecem os itens listados acima.
- Só o backend (Admin SDK) escreve saldos, extrato, amizades, partidas e desafios; as Security Rules bloqueiam escrita direta pelo app, exceto a alteração do próprio nome de exibição.
- O backup pontual do Firestore estava desligado em 01/11/2026 e não foi reverificado; não há política de backup definida.

## 7. Pontos a decidir pela equipe antes de publicar

- Texto jurídico final, encarregado de dados e canal de contato.
- Se o e-mail devolvido pelo login por username é aceitável para o escopo do projeto.
- Prazo de retenção do extrato e dos desafios encerrados depois da exclusão.
- Idade mínima de uso.
