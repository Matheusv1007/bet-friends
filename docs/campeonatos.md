# Campeonatos suportados

O BetFriends começou só com o Campeonato Brasileiro Série A (`BSA`). Em 23/11/2026 a temporada brasileira estava perto do fim (última partida em 03/12/2026) e a apresentação do projeto é em dezembro. Por isso o app passou a sincronizar e listar quatro campeonatos, para sempre haver partidas reais futuras na demonstração e para o app continuar útil depois da temporada brasileira. É uma decisão acadêmica de escopo, não uma mudança nas regras do jogo.

| Código | Campeonato | Temporada usada | Observação |
|---|---|---|---|
| `BSA` | Campeonato Brasileiro Série A | 2026 (28/01 a 02/12/2026) | Continua na lista; termina em 03/12/2026 |
| `PL` | Premier League | 2026/27 (21/08/2026 a 30/05/2027) | Salvo como `season` 2026 |
| `SA` | Serie A (Itália) | 2026/27 (23/08/2026 a 30/05/2027) | Salvo como `season` 2026 |
| `PD` | La Liga (`Primera Division` na API) | 2026/27 (16/08/2026 a 30/05/2027) | Salvo como `season` 2026 |

## Disponibilidade confirmada na API (23/11/2026)

Consulta feita com o token do projeto (Secret Manager), sem registrar o token:

| Campeonato | HTTP | Partidas nos próximos 14 dias | Partidas restantes na temporada |
|---|---|---|---|
| BSA | 200 | 24 | 24 |
| PL | 200 | 31 | 270 |
| SA | 200 | 21 | 260 |
| PD | 200 | 23 | 250 |

- As quatro competições estão no plano gratuito do projeto (limite de 10 chamadas por minuto).
- `competition.code` vem como `BSA`, `PL`, `SA` e `PD`, e `crest` como PNG.
- **Sem o parâmetro `season`** a API devolve a temporada atual, então o backend não o envia: a virada de temporada não exige mudança de código.
- Partidas restantes em dezembro de 2026: BSA 10, PL 60, SA 30, PD 32; em janeiro de 2027: PL 49, SA 60, PD 50. Pausas de fim de ano não foram conferidas jogo a jogo.

## Como funciona

**Backend**
- A lista vem de `PARTIDAS_SYNC_COMPETICOES` (padrão `BSA,PL,SA,PD`; 1 a 8 códigos; ver `docs/callable-functions.md` §10).
- Cada execução de `syncMatches` faz uma chamada por competição, **em série**, nunca em paralelo: 4 chamadas a cada 5 minutos, abaixo do limite de 10 por minuto.
- Cada competição tem o seu estado, `system/matchSync_{código}` (`docs/firestore-schema.md` §3.7), com escopo, varredura da temporada e contagem de falhas próprios.
- Falha de uma competição (`indisponivel`, `resposta-invalida`) não interrompe as outras. HTTP 429 e credencial recusada interrompem o restante da execução (mesma cota e mesmo token): as competições não consultadas ficam intactas e passam à frente na execução seguinte.
- O `matches` continua com o mesmo modelo e o mesmo ID determinístico `footballdata_{id}`, único entre competições. Nada é migrado nem apagado.
- A primeira execução depois do deploy faz 4 varreduras da temporada (cerca de 380 partidas cada; ~1.140 documentos novos). `timeoutSeconds` subiu de 240 para 280.

**App**
- O app consulta cada competição suportada separadamente, com os índices que já existiam (`competitionCode`, `startsAtUtc`).
- A Home mostra até 15 partidas, intercaladas entre as ligas, com o nome do campeonato no card e nos detalhes.
- Criar Desafio lista as partidas elegíveis das quatro ligas, mostra a liga em cada item e tem filtro (Todos, Brasileirão, Premier League, Serie A, La Liga). O filtro só afeta o que é exibido: a partida já selecionada continua visível e o envio usa todas as elegíveis.

## Impacto nas regras de desafios e BetCoins

Nenhum. Criar, aceitar, bloquear 5 minutos antes do início, iniciar, liquidar e devolver reservas funcionam pelo mesmo código, que não depende do campeonato; os testes de emulador provam o ciclo com partidas de `BSA`, `PL`, `SA` e `PD`. A única mudança de regra é a base do cancelamento por tempo (T-01), agora **por liga**: a varredura de uma competição nunca libera o cancelamento de partida de outra.

## Limitações e riscos

- **Leituras do Firestore (estimativa, não medida):** cerca de 4 vezes as de antes por execução. Cálculo aproximado: ~100 a 150 leituras por execução só com janelas e ~1.500 quando as 4 temporadas são varridas. Se a cota gratuita apertar, aumentar `PARTIDAS_SYNC_AGENDA` (por exemplo, `every 10 minutes`) ou retirar uma competição da lista.
- **Liga retirada da lista:** os desafios dela deixam de sair por tempo (T-01) até ela voltar à lista; liquidação e cancelamento por partida `CANCELADA` continuam normais.
- **Brasileirão depois de 03/12/2026:** pode continuar na lista (custo baixo) ou ser retirado pelo `.env`.
- **Escudos:** as ligas europeias usam a mesma URL de escudo do provedor já adotada para o Brasileirão (projeto acadêmico, não hospedado); as marcas pertencem aos clubes.
- **Partidas já finalizadas** continuam sem escudo na sincronização (regra anti-regressão).
- Não foi medido em produção o tempo real de uma execução com 4 varreduras.

## Publicação segura (o que fazer, em ordem)

Só `syncMatches` muda de comportamento no backend; o app novo é compatível com o backend antigo e o app antigo continua lendo só `BSA`. Não há índice novo nem mudança de regras.

1. Conferir o estado atual e anotar o commit: `npx firebase-tools@15.32.1 functions:list --project betfriends-unirv-2026`.
2. Publicar **somente** a função agendada (Node 22 no PATH, `docs/callable-functions.md` §9):
   `npx firebase-tools@15.32.1 deploy --only functions:syncMatches --project betfriends-unirv-2026`.
   Nunca `--force`, nunca remover função e nunca publicar regras ou índices que a mudança não alterou.
3. Esperar uma ou duas execuções (5 a 10 minutos) e conferir no Firestore: `matches` com partidas de `PL`, `SA` e `PD`; `system/matchSync_BSA`, `_PL`, `_SA` e `_PD` com `lastSeasonSuccessAt`; nos logs do `syncMatches`, "Sincronização de partidas concluída" por competição e nenhum `sincronizacao-falhou`.
4. **Reversão:** publicar de novo `functions:syncMatches` a partir do commit anterior. Os documentos já gravados em `matches` e `system/` são inofensivos para a versão antiga (ela só lê o BSA e usa `system/matchSync`).

## Como validar no emulador Android

1. Depois da publicação e das primeiras execuções, `flutter run -d emulator-5554` (ver `docs/rodando-em-2-terminais.md`) com contas de teste que sejam amigas.
2. Home: aparecem partidas das quatro ligas, intercaladas por horário, com o nome da liga em cada card; os detalhes mostram "Premier League • Rodada N" (e equivalentes).
3. Criar Desafio: os chips mostram as cinco opções; filtrar por La Liga mostra só jogos da La Liga; "Mostrar mais" funciona dentro do filtro; abrir os detalhes de uma partida e tocar em Desafiar mantém essa partida visível mesmo com outro filtro.
4. Criar um desafio sobre uma partida da Premier League, aceitar com a outra conta (palpite diferente) e conferir os saldos reservados.
5. A liquidação só acontece quando a partida real termina e a sincronização traz o resultado; para a apresentação, escolher uma partida que termine antes do ensaio. A prova automatizada do ciclo completo está em `functions/test/campeonatos.emulator.test.ts`.

## Sugestões de atualização do Jira e do Plano Mestre

- **Jira:** card "Ampliar campeonatos: Premier League, Serie A e La Liga" com subtarefas: configuração das competições; sincronização em série com estado por liga e tratamento de 429; T-01 por liga; consulta por liga no app; identificação da liga e filtro em Criar Desafio; documentação e validação. Motivo: o Brasileirão termina em 03/12/2026 e a apresentação é em dezembro.
- **Plano Mestre v3.2:** RF-007 e RF-008 falam de "partidas do campeonato" no singular; atualizar para os campeonatos `BSA`, `PL`, `SA` e `PD`, registrando que o escopo cresceu por motivo acadêmico, sem mudar a economia das BetCoins. D-015 (cache e uso da API) passa a considerar 4 chamadas por execução.
