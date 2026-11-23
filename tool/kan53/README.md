# Medição do atraso do plano Free (KAN-53)

Mede o atraso observado entre um fato do jogo e o nosso Firestore, para orientar a frequência da sincronização. **É passiva:** só lê `matches/{partida}` e `system/matchSync`, nunca chama a Football-Data e nunca grava no Firebase. Não altera a agenda da `syncMatches`.

## O que é medido

| Horário | Origem | Observação |
|---|---|---|
| `t_evento` | Anotado à mão, de fonte externa | Inclui o atraso da fonte; informe a tolerância em `tolS` |
| `t_sistema` | `syncedAt` da partida | Quando o nosso sistema gravou a mudança |
| `t_observacao` | Cabeçalho `Date` da resposta do Firestore | Quando o coletor viu; não usa o relógio local |
| `t_execucao` | `system/matchSync.lastRunAt` | Permite limitar o atraso do provedor |

- **Atraso até o sistema:** `t_sistema − t_evento`.
- **Atraso do provedor:** um intervalo, porque só consultamos a cada execução. O mínimo vem da última execução que ainda não trouxe o evento, e o máximo, da que trouxe.
- **`providerLastUpdated`:** só registrado. Foi visto igual em várias partidas, então não marca um evento.

## Como executar

Antes do início do jogo, em um terminal separado, com o Firebase CLI autenticado:

```bash
node tool/kan53/coletar.mjs --partida footballdata_<id> --intervalo 30 --horas 4 \
  --firebase-tools <pasta do firebase-tools>
```

Os dados ficam em `~/.local/share/betfriends-kan53/`, fora do repositório. Durante o jogo, anote início, gols e fim em um arquivo de eventos (formato em `analisar.mjs`). Depois:

```bash
node tool/kan53/analisar.mjs ~/.local/share/betfriends-kan53/producao-footballdata_<id>.jsonl eventos.jsonl
```

`evidenciaReal` só é `true` com coleta de produção e pelo menos um evento medido.

## Testes

```bash
node --test tool/kan53/medicao.test.mjs
```

## Limites

- A precisão fica limitada pela agenda de 5 minutos e pela anotação manual, que herda o atraso da transmissão.
- Um gol anulado, ou dois gols na mesma execução, pode não ter mudança correspondente: a análise marca `sem-mudanca-correspondente`.
- Uma partida mede só aquele jogo. Recomenda-se mais de uma antes de decidir.
