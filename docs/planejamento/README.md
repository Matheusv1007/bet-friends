# Planejamento

Pasta para registrar auditorias, decisões e planos de trabalho antes de executá-los. Cada documento diz a data, a base de código e o que foi (ou não) verificado.

| Documento | Conteúdo | Situação |
|---|---|---|
| [`auditoria-visual.md`](auditoria-visual.md) | Auditoria do front end: 16 achados com imagens, estouros de layout, contraste e acabamento | Concluída em 23/11/2026 |
| [`direcao-visual.md`](direcao-visual.md) | Primeira rodada de direções (neon) e comparação de 7 fontes | Descartada pelo responsável em 23/11/2026 (neon e "cara de IA"); mantida como registro |
| [`direcoes-v2.md`](direcoes-v2.md) | Segunda rodada: 4 direções sóbrias (sem neon) e 8 fontes modernas | Aguardando decisão |
| [`plano-ui.md`](plano-ui.md) | Plano da rodada de melhoria visual: 7 branches, ordem e decisões pendentes | Proposta, não executada |

As imagens ficam em [`imagens/`](imagens/): `auditoria/` (telas renderizadas), `direcoes/` (primeira rodada de mockups, com acento neon, descartada) e `direcoes-v2/` (segunda rodada: direções sóbrias e fontes modernas).

## Como as imagens foram geradas

As telas foram renderizadas por um **harness de teste descartável** (`flutter test` com as fontes Roboto e MaterialIcons carregadas) usando os fakes dos testes do app, sem dispositivo nem Firebase. O app foi renderizado em 360x800 e 320x568, e as 8 telas principais também com texto em 1,5x e 2,0x (222 imagens no total; aqui estão as 17 mais relevantes). Os escudos aparecem como ícone genérico porque a renderização não tem rede, e os horários vêm do relógio da máquina.

O harness **não está versionado**: ficou num worktree local descartável. Se a rodada de melhoria visual for aprovada, ele pode ser recriado ou versionado para comparar antes e depois com as mesmas telas.

Os mockups das direções (`imagens/direcoes/` e `imagens/direcoes-v2/`) são desenhos feitos só para comparação, não implementação do app. Os da primeira rodada mostram itens que o app ainda não tem, como "Esqueci minha senha", sino de notificação e "Trocar" amigo.
