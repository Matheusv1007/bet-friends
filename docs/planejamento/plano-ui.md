# Plano da rodada de melhoria visual

**Data:** 23/11/2026 · **Base:** `qas` em `607a2ea` · **Situação:** proposta, **não executada** e aguardando as decisões abaixo. Origem: [`auditoria-visual.md`](auditoria-visual.md) e [`direcao-visual.md`](direcao-visual.md).

## Execução proposta

Uma rodada, com branches independentes e merge local numa branch de integração, como nas rodadas anteriores. A branch 1 vem antes das outras, porque define o tema que as demais usam.

| # | Branch | Escopo | Achados |
|---|---|---|---|
| 1 | `feature/ui-tema` | `AppTheme` (cores, escala de tipografia, 3 a 4 raios), tema de SnackBar, diálogos e campos, `SystemChrome`, fonte embutida | 1, 8, 9 (barra de status) |
| 2 | `feature/ui-home` | Carteira compacta, um único aviso de pendência, partidas e desafios mais acima, cabeçalho alinhado | 2, 11, 16 |
| 3 | `feature/ui-partidas-listas` | Layout vertical dos times, nomes de amigos, detalhes da partida, estouros de 320 e de texto 1,5x | 3, 4, 13, 14 |
| 4 | `feature/ui-formularios` | Login, Cadastro e diálogos com campos únicos e erro inline | 7 |
| 5 | `feature/ui-telas-novas` | Extrato, Histórico e Perfil no padrão das demais | 5, 12 |
| 6 | `feature/ui-marca` | Ícone, splash, nome do app, transições e esqueletos | 9, 15 |
| 7 | `feature/ui-acessibilidade` | Semântica, tamanho mínimo de fonte e teste de estouros | 10 |

Navegação (achado 6) depende da decisão 3.

**Verificação:** o harness de renderização é reaproveitado para comparar antes e depois, com as mesmas telas e tamanhos, além de `flutter analyze` e `flutter test`. Sem dispositivo Android, a validação visual final é do responsável no emulador.

## Regras de trabalho

Iguais às das rodadas anteriores: commits em português, sem co-autor, sem push; merges locais só por autorização explícita; deploys só se o responsável permitir (esta rodada não altera o backend).

## Decisões pendentes

| # | Pergunta | Sugestão | Resposta |
|---|---|---|---|
| 1 | Direção visual e fonte | Primeira e segunda rodadas viraram registro: o responsável quer manter a paleta atual sem neon. Protótipo em [`evolucao.md`](evolucao.md): confirmar a direção Evolução e a fonte (A: Schibsted Grotesk, sugerida; B: Bricolage com Instrument Sans) | Em avaliação |
| 2 | Pode reorganizar a ordem da Home e reduzir a carteira? É a mudança que mais altera o que a equipe já conhece | Sim | Pendente |
| 3 | Aba "Desafios": renomear ou criar uma tela de desafios de verdade (a segunda opção é maior) | Renomear primeiro | Pendente |
| 4 | Existe arte de marca (logo e ícone)? Sem ela, uma versão simples feita com formas, só para trocar o ícone padrão | Versão simples | Pendente |
| 5 | Escudos: manter o quadro branco atrás deles ou usar um fundo neutro | Avaliar com escudos reais no emulador | Pendente |

## Fora do escopo

Backend, regras de desafio e BetCoins, e novas funcionalidades. Os itens de mockup que o app não tem (por exemplo, "Esqueci minha senha", notificações e "Trocar" amigo) não fazem parte desta rodada.
