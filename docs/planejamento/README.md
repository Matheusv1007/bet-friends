# Planejamento

Pasta para registrar auditorias, decisões e planos de trabalho antes de executá-los. Cada documento diz a data, a base de código e o que foi (ou não) verificado.

| Documento | Conteúdo | Situação |
|---|---|---|
| [`auditoria-visual.md`](auditoria-visual.md) | Auditoria do front end: 16 achados com imagens, estouros de layout, contraste e acabamento | Concluída em 23/11/2026 |
| [`direcao-visual.md`](direcao-visual.md) | Primeira rodada de direções (neon) e comparação de 7 fontes | Descartada pelo responsável em 23/11/2026 (neon e "cara de IA"); mantida como registro |
| [`direcoes-v2.md`](direcoes-v2.md) | Segunda rodada: 4 direções sóbrias com paletas novas (Gramado, Jornal, Carvão, Marinho) e 8 fontes modernas | Registro; o responsável pediu manter a paleta atual |
| [`evolucao.md`](evolucao.md) | Direção "Evolução": paleta atual sem neon, sistema de design e 8 telas redesenhadas (antes e depois) | Implementada; protótipo preservado como referência |
| [`plano-ui.md`](plano-ui.md) | Plano da rodada de melhoria visual: etapas, decisões e evidências | Concluída localmente; 644 testes passando |

As imagens ficam em [`imagens/`](imagens/): `auditoria/` (telas renderizadas), `direcoes/` (primeira rodada, com acento neon, descartada), `direcoes-v2/` (segunda rodada: paletas novas e fontes modernas), `evolucao/` (protótipo aprovado) e `implementacao/` (telas reais após a integração).

## Como as imagens foram geradas

As telas foram renderizadas por um **harness de teste descartável** (`flutter test` com as fontes Roboto e MaterialIcons carregadas) usando os fakes dos testes do app, sem dispositivo nem Firebase. O app foi renderizado em 360x800 e 320x568, e as 8 telas principais também com texto em 1,5x e 2,0x (222 imagens no total; aqui estão as 17 mais relevantes). Os escudos aparecem como ícone genérico porque a renderização não tem rede, e os horários vêm do relógio da máquina.

O harness de imagens **não está versionado**. A implementação preserva as capturas em `imagens/implementacao/` e os cenários de regressão em `test/evolucao_layout_test.dart`, com fakes sem Firebase em `test/support/backend_ui.dart`. As capturas posteriores carregam Schibsted Grotesk e MaterialIcons; continuam sem dispositivo e sem rede.

Os mockups das direções (`imagens/direcoes/`, `imagens/direcoes-v2/` e `imagens/evolucao/`) são desenhos feitos só para comparação, não implementação do app. Os da primeira rodada mostram itens que o app ainda não tem, como "Esqueci minha senha", sino de notificação e "Trocar" amigo.
