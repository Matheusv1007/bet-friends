# Changelog

Formato inspirado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/). O projeto ainda não tem releases publicados: a versão do app é `1.0.0+1` (`pubspec.yaml`) e as mudanças abaixo entram na versão 1.0.0 do MVP.

## [Não lançado] — MVP

### Adicionado

- **Quatro campeonatos (`BSA`, `PL`, `SA`, `PD`):** `syncMatches` sincroniza, em série e com estado próprio por competição (`system/matchSync_{código}`), o Brasileirão, a Premier League, a Serie A e La Liga; o app lista as quatro com o nome do campeonato nos cards e nos detalhes e tem filtro por liga em Criar Desafio. Lista configurável por `PARTIDAS_SYNC_COMPETICOES`; ver [`docs/campeonatos.md`](docs/campeonatos.md).
- **Login por e-mail ou username.** Nova callable pública `resolveLoginEmail` (limite de 10 consultas por minuto por IP); username inexistente falha como credencial inválida.
- **Escudos dos times** na Home, nos detalhes da partida e na escolha de partida do desafio, a partir da URL do provedor (PNG ou SVG, `flutter_svg`), com disco e sigla do clube quando não há imagem. A tela de créditos informa a origem.
- **Criar desafio:** lista as 5 primeiras partidas elegíveis, com "Mostrar mais".
- **Resultado oficial e efeito nos BetCoins** nos desafios finalizados.
- **Bônus de recuperação (RF-020):** ação na Home, visível só quando há direito ao bônus, com a hora do próximo resgate no intervalo de 24 horas.
- **Histórico de desafios encerrados (RF-021):** tela paginada aberta por "Ver todos".
- **Extrato de BetCoins (RF-019):** tela paginada a partir do Perfil, com índice novo de `betCoinTransactions`.
- **Remover amizade (RF-006):** callable `removeFriend`, bloqueada enquanto houver desafio `PENDING`, `ACCEPTED`, `IN_PROGRESS` ou `WAITING_RESULT` entre os dois; nova amizade exige novo aceite.
- **Exclusão de conta (N-14):** callable `deleteAccount` com reautenticação por senha, bloqueios por desafio ativo e saldo reservado, limpeza em lotes retomável e apagamento do usuário no Authentication por último.

### Corrigido

- **T-01:** as saídas por tempo do cancelamento (`ACCEPTED` e `WAITING_RESULT`) só valem se a sincronização da temporada inteira ocorreu depois do prazo de 7 dias; com a sincronização parada nada é cancelado por tempo.
- **T-02:** o app segue o cursor de `getFriendRequests` ("Carregar mais" nas solicitações).
- **T-05 (parcial):** nomes dos adversários são recarregados e lembrados; quem nunca foi visto aparece como "Jogador". Resolver o nome de um ex-amigo nunca visto exige consulta pública por UID no backend.

### Alterado

- **Interface Evolução:** tema escuro centralizado, Schibsted Grotesk embutida, componentes compartilhados, erros inline e layouts responsivos. Home com saldo compacto, aviso único, prêmio líquido e recusa com confirmação; aba **Desafiar**; partidas em duas linhas; Perfil agrupado; Extrato, Histórico e Amigos no mesmo padrão. Marca aplicada ao app, ícone adaptativo e abertura Android escura. Evidências e decisões em [`docs/planejamento/plano-ui.md`](docs/planejamento/plano-ui.md).

- `createChallenge` passa a atualizar `updatedAt` da amizade na mesma transação, para serializar com a remoção de amizade.
- Operações de amizade, desafio, reserva, criação de perfil e busca consultam a guarda `accountDeletions/{uid}` durante a exclusão de conta.
- `functions/src/index.ts` exporta 17 funções: 16 callables e a agendada `syncMatches`.

### Pendente

- Itens de release listados em [`docs/auditoria/quarta-auditoria.md`](docs/auditoria/quarta-auditoria.md): keystore de release, `LICENSE`, App Check, Crashlytics e backup do Firestore.
