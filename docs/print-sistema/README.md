# Prints do sistema BetFriends

Sequência de capturas de tela que mostra o fluxo do aplicativo, da entrada na conta até o logout. Cada imagem tem 1280 × 2856 px (densidade 480 dpi), tirada direto do emulador `Pixel_10_Pro` (Android).

## Como as capturas foram feitas

- **Dados fictícios.** O app real usa o Firebase da equipe. Para não gravar nada lá nem usar contas de teste, o app foi executado com o backend **simulado em memória** (Auth, perfil, partidas, amizades, desafios, extrato e histórico). A interface, os fluxos e as regras de tela são os do código em `lib/`; só a camada de dados é falsa.
- **Conta de demonstração:** Ana Lima (`@AnaL`), 1.250 BetCoins no total, 350 reservados em desafios abertos. Os amigos (Bruno, Carla, Diego, Elisa, Felipe, Gabriela) e as partidas (Brasileirão, Premier League, Serie A, La Liga) também são fictícios.
- **As ações foram executadas de verdade na tela** (criar desafio, aceitar, aceitar amizade, editar nome...). Por isso o saldo e as listas mudam de uma imagem para a outra: o saldo cai de 900 para 800 ao criar o desafio e para 700 ao aceitar outro.
- A hora da barra de status (9:30) foi fixada para padronizar as imagens.

### Limites

- **Extrato (21)** e **Histórico (22)** mostram lançamentos de exemplo; eles não refletem as ações feitas nas imagens anteriores.
- **Bônus de recuperação** não aparece: só é oferecido com saldo disponível abaixo de 10 BetCoins e depende da Cloud Function `claimRecoveryBonus`.
- A imagem **10** mostra o botão "Desafiar nesta partida", mas a criação do desafio foi feita pela aba **Desafiar** (imagens 11 a 14), que leva às mesmas telas.
- O cadastro (03 e 04) mostra apenas o formulário; não foi enviado, para não criar conta.
- Não há captura de erros de rede nem do modo offline.

---

## 1. Acesso à conta

| Imagem | O que mostra |
|---|---|
| `01-login.png` | **Tela de login.** Logo, campos "E-mail ou usuário" e "Senha" (com botão para mostrar/ocultar), botão **Entrar** e link **Criar conta**. É a tela exibida quando não há sessão ativa. |
| `02-login-preenchido.png` | Login com e-mail preenchido e senha oculta (pontos), pronto para **Entrar**. |
| `03-cadastro.png` | **Criar conta.** Formulário com nome completo, nome de usuário (3 a 20 caracteres: letras, números e `_`; não muda depois), e-mail, senha (mínimo de 6 caracteres) e confirmação de senha. |
| `04-cadastro-preenchido.png` | Cadastro preenchido, pronto para **Cadastrar**. Ao concluir, a conta nasce com 1.000 BetCoins. |

## 2. Home

| Imagem | O que mostra |
|---|---|
| `05-home.png` | **Home logada.** Saudação com o nome do perfil, cartão de saldo (**900** disponíveis, 350 reservados, total 1.250), botões **Extrato** e **Novo desafio**, alerta amarelo "2 desafios aguardando você" com atalho **Responder**, e a lista de partidas com ligas, rodada, placar ao vivo (**AO VIVO 67'**) e botão **Desafiar** nos jogos futuros. A barra inferior tem **Home / Desafiar / Perfil**. |
| `06-home-desafios-recebidos.png` | Seção **Recebidos**: desafios que outros amigos enviaram. Cada cartão traz quem desafiou, partida, horário, palpite do criador, valor, prêmio e os botões **Responder** e **Recusar**. |
| `07-home-desafios-enviados-ativos.png` | Seção **Enviados** (desafios aguardando o amigo, com **Cancelar**) e **Em aberto** (desafios ativos, com a etiqueta de estado **ACEITO** ou **EM ANDAMENTO**). |
| `08-home-desafios-finalizados.png` | Seção **Finalizados**, com o resultado de cada desafio: **Você venceu! +100**, **Você perdeu −150**, **Ninguém acertou** e **Partida adiada** (aposta devolvida). O link **Ver todos** abre o histórico completo (imagem 22). |
| `09-partidas-todas.png` | Lista de partidas expandida por **Ver todas**: Brasileirão, Premier League, Serie A e La Liga, com jogos ao vivo no topo e os próximos em seguida. |
| `10-detalhes-da-partida.png` | Detalhes de uma partida (toque no cartão): campeonato e rodada, times, data, horário local, status e o botão **Desafiar nesta partida**. |

## 3. Criar um desafio

| Imagem | O que mostra |
|---|---|
| `11-criar-desafio-partida.png` | Tela **Criar desafio**, aberta pela aba **Desafiar**. Filtro por campeonato (Todos, Brasileirão, Premier League, Serie A...) e a lista das próximas partidas elegíveis (as 5 primeiras, com **Mostrar mais**). |
| `12-criar-desafio-palpite-valor-amigo.png` | Com **Arsenal x Chelsea** escolhida, a mesma tela rolada: **Seu palpite** (mandante, empate ou visitante), **Valor** (10, 25, 50 ou 100), o resumo "Você aposta 50 / Prêmio se acertar +50" e a lista de **Amigo** aceitos. O saldo disponível (900) aparece ao lado de "Valor". |
| `13-criar-desafio-preenchido.png` | Formulário pronto: palpite **Empate**, valor **100**, amigo **Bruno Alves**, antes de tocar em **Enviar desafio**. |
| `14-desafio-enviado-confirmacao.png` | Retorno à Home com a mensagem **"Desafio criado com sucesso! BetCoins reservadas."** O saldo disponível já caiu para **800** (reservado 450): o valor da aposta fica reservado até o desafio terminar. |
| `15-home-desafio-enviado-novo.png` | Seção **Enviados** com o desafio novo ("Aguardando Bruno Alves", Arsenal x Chelsea, palpite Empate, valor 100) ao lado do enviado anteriormente. |

## 4. Responder desafios recebidos

| Imagem | O que mostra |
|---|---|
| `16-responder-desafio.png` | **Aceitar desafio** (toque em **Responder**): quem desafiou, partida, valor, palpite do criador e prêmio. O usuário escolhe o seu palpite, que **precisa ser diferente** do palpite do criador (aqui, Empate ou Vitória Visitante). Botões **Confirmar e aceitar** e **Recusar desafio**. |
| `17-desafio-aceito-confirmacao.png` | Mensagem **"Desafio aceito com sucesso! Suas BetCoins foram reservadas."** O desafio sai de **Recebidos** e entra em **Em aberto** (agora 3 ativos), com a etiqueta **ACEITO**. |
| `18-recusar-desafio-confirmacao.png` | Confirmação de **Recusar** um desafio recebido: avisa que as BetCoins reservadas pelo criador voltam para o saldo dele. **Voltar** mantém o desafio. |
| `19-detalhes-do-desafio.png` | **Detalhes do desafio** (toque em um desafio em aberto): partida, horário, aposta, estado, criador e desafiado com o palpite de cada um. |
| `20-home-saldo-atualizado.png` | Topo da Home depois das duas operações: saldo disponível **700**, reservado **550**, total **1.250**, e o alerta agora com "1 desafio aguardando você". O total não muda: criar e aceitar só movem BetCoins entre disponível e reservado. |

## 5. Carteira e histórico

| Imagem | O que mostra |
|---|---|
| `21-extrato.png` | **Extrato de BetCoins** (link **Extrato** da Home ou item no Perfil): resumo Disponível / Reservado / Total e os lançamentos do mais recente ao mais antigo: reserva, prêmio por vitória, perda, reembolso por empate, liberação de reserva, bônus de recuperação e saldo inicial. |
| `22-historico-de-desafios.png` | **Histórico de desafios** (**Ver todos** em Finalizados): todos os desafios encerrados com o resultado de cada um: vitória, derrota, empate, partida adiada, recusado e expirado. |

## 6. Menu da conta e informações

| Imagem | O que mostra |
|---|---|
| `23-menu-da-conta.png` | Menu aberto pelo avatar no canto superior da Home: **Informações e Créditos** e **Sair da conta**. |
| `24-informacoes-e-creditos.png` | **Informações e créditos**: versão do app, crédito obrigatório "Dados fornecidos por football-data.org", licenciamento dos escudos e finalidade do aplicativo (projeto acadêmico, BetCoins sem valor monetário). |

## 7. Perfil

| Imagem | O que mostra |
|---|---|
| `25-perfil.png` | **Perfil** (aba Perfil): nome de exibição e `@username`, botão **Editar**, e os atalhos **Extrato de BetCoins**, **Meus amigos**, **Buscar amigos**, **Solicitações de amizade** e **Informações e créditos**. Na **Zona de risco**, o botão **Excluir conta**. |
| `26-editar-nome.png` | Diálogo **Editar nome de exibição** (1 a 60 caracteres; o username não muda). |
| `27-nome-atualizado.png` | Nome salvo: o cabeçalho e o campo mostram o novo nome e aparece "Nome de exibição atualizado." |
| `36-excluir-conta-confirmacao.png` | Diálogo **Excluir conta**: explica o que é apagado (perfil, amizades e pedidos), exige digitar o username e a senha atual. Não foi confirmado. |

## 8. Amizades

| Imagem | O que mostra |
|---|---|
| `28-solicitacoes-de-amizade.png` | **Solicitações de amizade** recebidas, com a etiqueta **PENDENTE** e os botões **Aceitar** e **Recusar**. |
| `29-solicitacao-aceita.png` | Após aceitar Henrique: ele sai da lista e aparece "Você e Henrique Souza agora são amigos!" |
| `30-meus-amigos.png` | **Meus amigos**: filtro por nome ou `@username`, contador (7 amigos, já com o Henrique) e, em cada cartão, **Desafiar** e o menu "…". No topo, atalhos para buscar novos amigos e para as solicitações. |
| `31-amigo-mais-opcoes.png` | Menu "…" de um amigo, com a opção **Remover amizade**. |
| `32-remover-amizade-confirmacao.png` | Confirmação de remoção: avisa que os dois só poderão se desafiar de novo se voltarem a ser amigos e que o histórico de desafios é mantido. Foi cancelada. |
| `33-buscar-amigos.png` | **Buscar usuários**, antes de digitar: orienta a digitar ao menos 3 letras do `@username`. |
| `34-buscar-amigos-resultados.png` | Resultados da busca por "mar", cada um com o botão **Convidar**. |
| `35-convite-enviado.png` | Após convidar Mariana: o botão vira a etiqueta **PENDENTE** e aparece "Solicitação de amizade enviada para Mariana Costa!" |

## 9. Sair

| Imagem | O que mostra |
|---|---|
| `37-sair-da-conta-confirmacao.png` | Confirmação de **Sair da conta** ("Você precisará entrar novamente para acessar o BetFriends."). Ao confirmar, o app volta à tela de login (imagem 01). |
