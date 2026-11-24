# Uso da marca BetFriends

Os arquivos originais estão em [`BetFriends_Kit_Logo/`](BetFriends_Kit_Logo/). O app usa cópias **aparadas** (sem a margem do kit) em `assets/brand/`, carregadas por `LogoBetFriends` (`lib/widgets/logo_bet_friends.dart`). No Android, o ícone e a abertura saem do monograma (ver o final deste documento).

## Cores da marca

| Cor | Hex | Uso |
|---|---|---|
| Fundo | `#0E141C` | Fundo do app, do ícone e da abertura; nome do logo na versão para fundos claros |
| Texto / "B" | `#E8ECF1` | Letra B e nome nas versões para fundo escuro |
| Verde / "F" | `#45A880` | Letra F; mesma cor de `CoresApp.primario` |

Fora disso, a marca não usa outras cores. Não há gradiente, brilho nem sombra.

## Qual arquivo usar

| Arquivo | Versão | Fundo | Quando |
|---|---|---|---|
| `01_logo_principal_horizontal.png` | Horizontal (símbolo + nome) | **Escuro** | Padrão: cabeçalhos, Login, Cadastro |
| `07_logo_para_fundos_claros.png` | Horizontal, nome em `#0E141C` | **Claro** | Documentos, apresentações e site em fundo claro |
| `02_logo_vertical.png` | Vertical (símbolo sobre o nome) | Escuro | Áreas altas e estreitas, telas de abertura e materiais verticais |
| `03_monograma_bicolor.png` | Monograma BF (B claro, F verde) | Escuro | Ícone do app, abertura, avatar de redes |
| `04_monograma_branco.png` | Monograma `#E8ECF1` | Escuro | Uma cor só; base da camada monocromática do ícone (Android 13+) |
| `05_monograma_azul_escuro.png` | Monograma `#0E141C` | Claro | Uma cor só em fundo claro |
| `06_monograma_verde.png` | Monograma `#45A880` | Escuro ou neutro | Uma cor só, destaque |

As versões 01, 02, 03, 04 e 06 foram feitas para fundo **escuro**. O verde `#45A880` perde contraste em fundo claro, então em fundo claro use **só** a `07` (horizontal) ou a `05` (monograma).

## Proporções reais

Medidas dos arquivos aparados (largura × altura):

| Versão | Aparado | Proporção |
|---|---|---|
| Horizontal (01, 07) | 2200 × 257 | 8,56 : 1 |
| Vertical (02) | 1180 × 846 | 1,39 : 1 |
| Monograma (03 a 06) | 790 × 333 | 2,37 : 1 |

Os arquivos do kit trazem margem própria (horizontal: 100 px nos lados e 201 px em cima e embaixo, em 2400 × 660). No app, use sempre `LogoBetFriends` e informe só a altura **ou** a largura; a outra medida sai da proporção.

## Área de respeito e tamanho mínimo

- **Área de respeito:** meia altura do logo aparado em todos os lados (a "altura" é a do próprio arquivo aparado: 257 na horizontal, 846 na vertical, 333 no monograma). Nada entra nessa faixa: texto, borda, outro logo.
- **Tamanho mínimo** (para o nome e o corte do B e do F continuarem legíveis):

| Versão | Altura mínima | Largura equivalente |
|---|---|---|
| Horizontal | 20 dp | ≈ 171 dp |
| Vertical | 48 dp | ≈ 67 dp |
| Monograma | 16 dp | ≈ 38 dp |

Alturas padrão no app: horizontal 32 dp, vertical 120 dp, monograma 40 dp.

## Onde cada versão é usada no app

| Lugar | Versão |
|---|---|
| Login e Cadastro | Horizontal (01) |
| Cabeçalho da Home | Horizontal (01) |
| Abertura (Android) | Monograma bicolor (03) sobre `#0E141C` |
| Ícone do app | Monograma bicolor (03) sobre `#0E141C`; camada monocromática com a 04 |

### No Android

- **Ícone adaptativo** (Android 8+): fundo `#0E141C` (cor `bf_fundo`), monograma ocupando 56% da largura da camada de 108 dp, o que o mantém dentro da zona segura (círculo de 66 dp) em máscara circular, quadrada ou *squircle*. A camada monocromática (Android 13+) usa a mesma forma em uma cor só.
- **Ícones legados** (`mipmap-*/ic_launcher.png` e `ic_launcher_round.png`): mesma composição em quadrado arredondado e em círculo.
- **Abertura:** fundo `#0E141C` nos modos claro e escuro. Android 12+ usa `windowSplashScreenBackground` e `splash_icon` (monograma dentro do círculo de 192 dp exigido pelo sistema); versões anteriores usam `launch_background` com `launch_logo`.

Os PNGs do Android são gerados a partir do kit (`03` e `04`); se o monograma mudar, regenere todos juntos.

## O que não fazer

- Não esticar nem comprimir: respeite a proporção do arquivo (use `LogoBetFriends`, que a mantém).
- Não trocar as cores, inclusive para "combinar" com o tema; só as variantes do kit.
- Não usar o logo com verde (01, 02, 03, 06) sobre fundo claro; nesse caso, use a `07` ou a `05`.
- Não colocar o logo sobre fotos ou fundos com ruído, nem sobre cores que reduzam o contraste do B ou do F.
- Não adicionar brilho, sombra, contorno, gradiente ou efeito.
- Não girar nem inclinar o logo; o monograma já é inclinado de origem.
- Não reduzir abaixo do tamanho mínimo nem invadir a área de respeito.
- Não recriar o logo com texto ou fonte; use sempre os arquivos do kit.
