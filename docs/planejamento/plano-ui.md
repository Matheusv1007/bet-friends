# Plano da rodada de melhoria visual

**Data:** 23/11/2026 · **Base:** `qas` em `607a2ea` · **Situação:** implementada e integrada localmente em `feature/correcao-pos-mvp`. Origem: [`auditoria-visual.md`](auditoria-visual.md) e [`direcao-visual.md`](direcao-visual.md).

## Execução realizada

Tema integrado primeiro; telas e marca desenvolvidas em branches independentes e mescladas localmente. A etapa 7 e os ajustes finais de integração foram concluídos diretamente em `feature/correcao-pos-mvp`. Sem push, PR ou deploy.

| # | Branch | Escopo | Achados |
|---|---|---|---|
| 1 | `feature/ui-tema` | `AppTheme` (cores, escala de tipografia, 3 a 4 raios), tema de SnackBar, diálogos e campos, `SystemChrome`, fonte embutida | 1, 8, 9 (barra de status) |
| 2 | `feature/ui-home` | Carteira compacta, um único aviso de pendência, partidas e desafios mais acima, cabeçalho alinhado | 2, 11, 16 |
| 3 | `feature/ui-partidas-listas` | Layout vertical dos times, nomes de amigos, detalhes da partida, estouros de 320 e de texto 1,5x | 3, 4, 13, 14 |
| 4 | `feature/ui-formularios` | Login, Cadastro e diálogos com campos únicos e erro inline | 7 |
| 5 | `feature/ui-telas-novas` | Extrato, Histórico e Perfil no padrão das demais | 5, 12 |
| 6 | `feature/ui-marca` | Ícone, splash, nome do app, transições e esqueletos | 9, 15 |
| 7 | Etapa na branch de integração | Semântica, tamanho mínimo de fonte e teste de estouros | 10 |

Navegação (achado 6): aba renomeada para **Desafiar**, preservando a abertura de Criar desafio.

**Verificação:** `flutter analyze` sem problemas; `flutter test`: **644 testes passando**. Harness descartável: **64 capturas sem registros de erro**, em 360×800 e 320×568, incluindo 320×568 com texto 2×. Regressão permanente: 12 telas em 320/360 dp e texto 1×/2× (48 cenários), com a fonte real. A branch de marca também gerou um APK debug. Sem aparelho ou emulador: ícone, splash nativo e escudos de rede ainda precisam de conferência no Android.

## Regras de trabalho

Iguais às das rodadas anteriores: commits em português, sem co-autor, sem push; merges locais só por autorização explícita; deploys só se o responsável permitir (esta rodada não altera o backend).

## Decisões aplicadas

| # | Pergunta | Sugestão | Resposta |
|---|---|---|---|
| 1 | Direção visual e fonte | Evolução; fonte A | Implementado com Schibsted Grotesk embutida |
| 2 | Ordem da Home e carteira compacta | Sim | Sugestão aplicada: saldo → pendências → partidas → desafios |
| 3 | Aba de criação de desafios | Renomear primeiro | Sugestão aplicada: Desafiar, sem criar uma tela adicional |
| 4 | Marca | Kit fornecido pelo responsável | Logos aparados em 1×/2×/3×; monograma BF no ícone adaptativo e na abertura escura; nome BetFriends |
| 5 | Fundo dos escudos | Neutro | Círculo neutro; fallback com cor e sigla do clube. Conferência de escudos reais no Android não realizada |

## Fora do escopo

Backend, regras de desafio e BetCoins, e novas funcionalidades. Os itens de mockup que o app não tem (por exemplo, "Esqueci minha senha", notificações e "Trocar" amigo) não fazem parte desta rodada.
