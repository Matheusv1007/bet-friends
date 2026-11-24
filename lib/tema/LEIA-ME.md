# Tema e componentes

Base visual da direção Evolução (decisões em `docs/planejamento/evolucao.md`). Imports:
`package:betfriends/tema/tema.dart` (tokens) e `package:betfriends/widgets/componentes.dart` (componentes e `Tom`).

## Tokens

- `CoresApp`: `fundo`, `superficie1` (cartão, diálogo, sheet), `superficie2` (campo, tag), `filete`, `contorno`, `texto`, `textoSuave`, `primario` (+ `sobrePrimario`, `primarioSuave` para seleção), `atencao`, `destrutivo`. Nada de `Colors.*` nem hex nas telas.
- `RaiosApp`: `tag` 4, `chip` 8, `botao` 10, `cartao` 12 (e `bordaTag`, `bordaChip`, `bordaBotao`, `bordaCartao`).
- `EspacosApp`: `e4`, `e8`, `e12`, `e16`, `e20`, `e24`, `e32`; `margemDaTela` 16; `alvoDeToque` 48.
- `TextoApp`: `tituloDeTela` 22/700, `tituloDeBarra` 20/700, `secao` 12/600, `corpo` 15/400, `corpoForte` 15/600, `secundario` 13/400 suave, `minimo` 12/500, `saldo` 36/700 e `placar` 18/700 (tabulares). `TextoApp.tabular(estilo)` só para números puros, nunca para horários e datas. Nada abaixo de 12.
- `Tom`: `neutro`, `sucesso`, `atencao`, `destrutivo`, com `cor`, `fundo` (opaco) e `icone`.
- `TemaApp.escuro` já está no `MaterialApp`: `AppBar`, botões do Material, campos, chips, SnackBar, diálogo, sheet, divisor e listas saem estilizados sem `style:`. `TemaApp.barrasDoSistema` é aplicado em `main.dart` e no `AppBar`.

## Componentes (`lib/widgets/`)

| Componente | Uso |
|---|---|
| `CampoDeTexto(rotulo:, controller:, dica:, ajuda:, erro:, validator:, senha:, …)` | Rótulo acima, erro inline com ícone (`erro` do estado da tela ou `validator` de um `Form`), alternância de senha (tooltips "Mostrar senha"/"Ocultar senha"). A `Key` fica no widget externo; `enterText(find.byKey(k))` funciona |
| `BotaoPrimario`, `BotaoSecundario`, `BotaoDestrutivo`, `BotaoTexto` `(rotulo:, onPressed:, icone:, carregando:, pequeno:, larguraTotal:)` | Uma ação primária por tela. Com `carregando` ou enquanto o `Future` de `onPressed` não termina: indicador no lugar do ícone e toques ignorados. `pequeno`: altura visual 36, alvo 48. `onPressed: null` desabilita |
| `TagDeStatus('Ao vivo', Tom.atencao)` | Estado curto em caixa alta, raio 4 |
| `TituloDeSecao('Partidas', acao: BotaoTexto(…, pequeno: true))` | Cabeçalho de seção 12/600 caixa alta |
| `LinhaDeLista(titulo:, subtitulo:, leading:, trailing:, onTap:, divisor:)` | Linha de grupo (Perfil, menus), mínimo 48 dp; ponha dentro de um `Card` |
| `AvisoInline('2 desafios aguardando você', Tom.atencao, acao: …)` | Pendência ou erro na própria tela, em vez de SnackBar |
| `mostrarAviso(context, 'Desafio enviado.', tom: Tom.sucesso)` | SnackBar temático; substitui o que estiver aberto |
| `LogoBetFriends(variante: VarianteDoLogo.horizontal, altura: 32)` | Variantes `horizontal`, `horizontalFundoClaro`, `vertical`, `monograma`; informe `altura` ou `largura` |

## Fonte e assets

- `assets/fonts/SchibstedGrotesk.ttf` é variável (`wght` 400–900); `fontWeight` move o eixo (`test/tema/fonte_test.dart`). Licença OFL em `assets/fonts/OFL-SchibstedGrotesk.txt`, registrada no `LicenseRegistry`.
- `assets/brand/` traz o kit de `docs/marca/` aparado, em 1x, `2.0x` e `3.0x`.
- Em testes, `flutter_test` desenha com a fonte de teste; para ver a fonte real, carregue-a com `FontLoader` (ver `fonte_test.dart`).
