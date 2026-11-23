# Auditoria visual do front end

**Data:** 23/11/2026 · **Base:** `qas` em `607a2ea` · **Escopo:** telas do app Flutter (Login, Cadastro, Home, Criar Desafio, Perfil, Amigos, Histórico, Extrato, diálogos e modais) · **Objetivo:** melhorar a interface visualmente.

## Método e limites

- 222 telas renderizadas em PNG, com dados realistas e os fakes dos testes. Tamanhos: 360x800, 320x568 e, nas 8 telas principais, texto 1,5x e 2,0x.
- Análise de código: tema, cores, tipografia, raios, diálogos e SnackBars. Contraste calculado pela fórmula WCAG.
- **Limites:** não rodei o app em dispositivo; os escudos aparecem como ícone genérico (sem rede); os horários vêm do relógio da máquina. Itens marcados [INFERÊNCIA] não foram confirmados em execução.

## Visão geral

O app tem uma identidade clara (escuro com verde-neon) e uma paleta com contraste suficiente. Os problemas estão em **cinco frentes**: não há sistema de design nem tema; a Home enterra o conteúdo principal; textos quebram ou estouram em telas pequenas e com fonte grande; as telas novas (Extrato, Histórico, Perfil) fogem do padrão das demais; e faltam itens de acabamento (ícone, splash, SnackBars, movimento, acessibilidade).

## Números

| Medida | Valor |
|---|---|
| `ThemeData` no app | 0 |
| Arquivos com cores fixas (`Color(0xFF…)`) | 48 |
| Uso do verde `0xFF00D084` | 90 vezes |
| Raios de borda diferentes | 11 (4 a 24; 16, 14, 12 e 18 competem) |
| Tamanhos de fonte diferentes | 21 (10,5; 11,5; 12,5; 13,5; 14,5; 16,5…) |
| Textos de 9,5 a 11 px | cerca de 48 ocorrências |
| `Semantics` / `semanticLabel` | 0 |
| Animações, `Hero` ou transições próprias | 0 |
| SnackBars com cor própria | cerca de 23 de 66 (contagem aproximada) |
| Estouros de layout distintos | 25, todos horizontais |

## Achados

Prioridade: **A** alta, **M** média, **B** baixa.

| # | Pri. | Achado | Evidência | Sugestão |
|---|---|---|---|---|
| 1 | A | **Sem tema nem design system.** Cores, raios e tamanhos fixos em cada arquivo. Widgets que o app não estiliza (seleção de texto, rolagem, tooltips) herdam o Material padrão roxo | `lib/app.dart`; contagens acima | `AppTheme` com cores, escala de tipografia, 3 a 4 raios e componentes (card, campo, botão, chip, diálogo) |
| 2 | A | **A Home enterra o conteúdo principal.** O saldo aparece 4 vezes (cabeçalho, disponível, total e a equação "Disponível = Total − Reservado"). O alerta "você tem 2 desafios aguardando" repete o bloco "Desafios recebidos". A carteira e o "Desafio Rápido" ocupam a primeira tela inteira | [01](imagens/auditoria/01-home-topo.png), [02](imagens/auditoria/02-home-partidas-e-recebidos.png) | Carteira compacta, um único aviso de pendência, partidas e desafios mais acima |
| 3 | A | **Estouros de layout** (ver tabela abaixo) | [04](imagens/auditoria/04-home-celular-pequeno-320.png), [06](imagens/auditoria/06-criar-desafio-texto-2x.png), [08](imagens/auditoria/08-login-texto-2x.png) | Trocar `Row` rígidos por `Flexible`, `Wrap` ou colunas; limites de largura nas etiquetas |
| 4 | A | **Nomes de times quebram no meio.** Em Criar Desafio, "Internacional" vira "Internaciona/l" e "Athletico Paranaense" vira "Paranaens/e". No card da Home vira "Internacion…" e "Atlético de …". Com texto 2,0x as palavras se partem letra a letra | [05](imagens/auditoria/05-criar-desafio-pagina-inteira.png), [06](imagens/auditoria/06-criar-desafio-texto-2x.png), [02](imagens/auditoria/02-home-partidas-e-recebidos.png) | Layout vertical (escudo e nome acima do horário), nome em até 2 linhas, tamanho mínimo |
| 5 | A | **Telas novas fogem do padrão.** Extrato e Histórico usam título sem negrito e seta de voltar diferente (`arrow_back` contra `arrow_back_ios_new`). O Extrato tem borda preta, a abreviação "BC", só texto e "Desafio 1" sem contexto. O Histórico repete o botão "Resultado" em todas as linhas | [12](imagens/auditoria/12-extrato.png), [13](imagens/auditoria/13-historico.png) | Reusar os AppBar e cartões das outras telas, com ícone por tipo de lançamento |
| 6 | A | **Navegação enganosa.** A aba "Desafios" abre "Criar Desafio" por cima da Home e a aba selecionada nunca muda. O ícone é `sports_kabaddi`. O menu inferior só existe na Home, então Perfil e Amigos ficam sem ele | `barra_navegacao_home.dart`, `home_page.dart` | Renomear a aba ou criar a tela de desafios; ícone coerente com o app |
| 7 | M | **Campos de formulário inconsistentes.** O Login tem rótulo flutuante e o Cadastro só tem dica, que some ao digitar. O diálogo "Excluir conta" também só tem dica, e ela fica truncada ("Digite seu username: An…"). Os erros do Login saem como SnackBar, sem relação com o campo | [07](imagens/auditoria/07-login-erro.png), [09](imagens/auditoria/09-cadastro.png), [15](imagens/auditoria/15-dialogo-excluir-conta.png) | Componente único de campo com rótulo, ajuda e erro inline |
| 8 | M | **SnackBars sem estilo.** No Login o erro vira uma faixa cinza colada no rodapé, fora da identidade visual | [07](imagens/auditoria/07-login-erro.png) | Tema de SnackBar (flutuante, com cor e ícone por tipo) |
| 9 | M | **Acabamento do app.** Ícone de lançador provavelmente o padrão do Flutter [INFERÊNCIA: PNG 192x192 de 1,4 KB]. O nome no sistema é "betfriends" em minúsculas. A tela de abertura (`launch_background.xml`) é branca no modo claro, então há um clarão branco antes do app escuro. Não há `SystemChrome`: na captura da Home que você enviou, a hora e os ícones da barra de status quase não aparecem [INFERÊNCIA] | `android/app/src/main/res` | Ícone e splash de marca, nome "BetFriends", estilo da barra de status |
| 10 | M | **Acessibilidade.** Zero `Semantics`. Texto pequeno em cerca de 48 lugares. No Login com texto 2,0x o link "Criar conta" fica cortado e o toque não abre o Cadastro. O vermelho `0xFFEF4444` sobre cartão dá 4,44:1, abaixo de 4,5 para texto pequeno | [08](imagens/auditoria/08-login-texto-2x.png) | Semântica nos controles, mínimo de 12 px, vermelho mais claro para texto |
| 11 | M | **Hierarquia de cores ambígua.** O verde é a ação principal. O laranja aparece como ação ("Desafiar", "Responder") e como alerta ("pendente"). O botão "MAIS PARTIDAS", verde e largo, compete com o botão principal da tela | [02](imagens/auditoria/02-home-partidas-e-recebidos.png) | Papéis fixos: verde = primário, laranja = atenção, vermelho = destrutivo |
| 12 | M | **Perfil com muitos botões iguais.** São 5 botões de contorno empilhados, com caixa diferente ("Extrato de BetCoins" contra "MEUS AMIGOS"). Os dados repetem o cabeçalho, e "Nome de usuário: AnaL" não tem o "@". "Excluir conta" fica fora da primeira tela | [14](imagens/auditoria/14-perfil.png) | Lista de itens agrupada, um padrão só de caixa e ícone, zona de risco separada |
| 13 | M | **Detalhes da partida.** O valor de "Data e Hora" quebra em 4 linhas ("23/11/ 2026 às 22:39"). Há dois níveis de ação (botão verde grande e "Fechar") | [10](imagens/auditoria/10-detalhes-da-partida.png) | Valor ocupando a largura, data e hora em duas linhas |
| 14 | M | **Lista de amigos.** Os nomes são cortados ("Carla Mend…", "Diego Ferna…") porque o botão "DESAFIAR" ocupa muito espaço. O ícone de remover amizade é pequeno, sem rótulo e parecido com o de "adicionar" | [16](imagens/auditoria/16-amigos-lista.png), [17](imagens/auditoria/17-amigos-buscar.png) | Ação principal compacta, menu "…" para remover, nomes em até 2 linhas |
| 15 | B | **Sem movimento.** Nenhuma animação, `Hero` ou transição própria; carregamentos com spinner, não esqueleto | contagem em `lib/` | Transições curtas, esqueletos nas listas |
| 16 | B | **Cabeçalho da Home desalinhado.** O saldo é um `TextButton` de 48 px e fica deslocado em relação à saudação. A marca é só um ícone de bola mais o texto | `cabecalho_home.dart`; [01](imagens/auditoria/01-home-topo.png) | Alinhar à saudação e usar um logotipo de verdade |

## Estouros de layout

Todos são `RenderFlex overflowed ... on the right`. Nenhum estouro vertical nem outro erro de framework apareceu.

| Tela | 360x800 | 320x568 | texto 1,5x | texto 2,0x |
|---|---|---|---|---|
| Home | 1 | 4 | 2 | 4 |
| Modal de aceitar desafio | 1 | 1 | 2 | 3 |
| Criar Desafio | 0 | 0 | 1 | 2 |
| Login | 0 | 0 | 1 | 1 |
| Cadastro | 0 | 0 | 0 | 1 |
| Amigos: lista | 0 | 0 | 0 | 1 |

Pontos do código:
- `lib/widgets_home_page/desafios_recebidos_card.dart:30`: o badge "AGUARDANDO SUA RESPOSTA" estoura 36 px em 360x800 e 76 px em 320x568.
- `lib/widgets_home_page/card_de_carteira.dart:126`: estoura 25 px em 320x568.
- `lib/tela_criar_desafio/modal_aceitar_desafio.dart:210`: estoura com nomes longos (77 px e 117 px).
- `lib/tela_criar_desafio/seletor_valor_desafio.dart:41`, `tela_criar_desafio.dart:329`, `lib/telas_autenticacao/cadastro_page.dart:410` e `lib/tela_amigos/tela_lista_amigos.dart:507`: estouram com texto 1,5x ou 2,0x.

## Contraste (WCAG)

| Texto | Fundo | Razão |
|---|---|---|
| Cinza `8E9CAB` | cartão `151E2E` | 5,96 |
| Cinza `8E9CAB` | fundo `0B111D` | 6,74 |
| Cinza `94A3B8` | cartão `151E2E` | 6,52 |
| Verde `00D084` | cartão `151E2E` | 8,24 |
| `062319` no botão verde | `00D084` | 8,20 |
| Laranja `F59E0B` | cartão `151E2E` | 7,78 |
| Vermelho `EF4444` | cartão `151E2E` | **4,44** (abaixo de 4,5) |
| Vermelho `F87171` | cartão `151E2E` | 6,04 |

A paleta é boa. O único valor abaixo de 4,5 é o vermelho em texto pequeno.

## Pontos fortes (a preservar)

- Identidade escura com verde reconhecível e contraste suficiente.
- Login e Cadastro limpos, com campos arredondados e botão primário claro.
- Modal de aceitar desafio com boa organização (resumo, palpites, ação principal e recusa).
- Estados vazio, erro e carregamento existem nas telas principais, com mensagens em português.
