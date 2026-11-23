# Funcionalidades — situação atual

Atualizado em 23/11/2026 (base: `qas` em `90207cb` mais as branches da rodada final do MVP, ver [`CHANGELOG.md`](../../CHANGELOG.md)). O texto da Segunda Entrega (01/11/2026) foi substituído: naquela data amizades, desafios, extrato e histórico ainda não existiam no app.

Legenda: ✅ validado no app com o Firebase real (observado pela equipe) · 🧪 implementado e testado com fakes e emulador, **sem validação no app real ainda** · 🟡 parcial · ⏳ pendente · ➖ fora do MVP

Evidência de testes: ver a linha de base em [`docs/auditoria/quarta-auditoria.md`](../auditoria/quarta-auditoria.md). Nenhum `integration_test/` foi executado em dispositivo para estas entregas.

## Conta e sessão

| Funcionalidade | Situação | Observação |
|---|---|---|
| Cadastro, perfil, carteira inicial de 1.000 BetCoins | ✅ | KAN-25/31/32/72 |
| Login por e-mail ou username | ✅ | Callable `resolveLoginEmail`; expõe o e-mail a quem souber o username (ver política de privacidade) |
| Sessão restaurada e logout | ✅ | `AuthGate`; logout limpa o cache do Firestore |
| Editar nome de exibição | ✅ | O username é imutável |
| Comportamento sem conexão | ✅ | Dados salvos com aviso; sem escrita pendente |
| Excluir conta | 🧪 | Callable `deleteAccount` e diálogo no Perfil; o apagamento no Authentication real só será comprovado com uma conta descartável |

## Amizades

| Funcionalidade | Situação | Observação |
|---|---|---|
| Buscar usuários, enviar, aceitar e recusar solicitação | ✅ | Telas no Perfil; limites de uso no backend |
| Lista de amigos | ✅ | Nome e `@username` apenas |
| Paginação das solicitações recebidas (T-02) | 🧪 | "Carregar mais" quando há cursor |
| Remover amizade (RF-006) | 🧪 | Bloqueada com desafio `PENDING`, `ACCEPTED`, `IN_PROGRESS` ou `WAITING_RESULT` entre os dois |

## Partidas

| Funcionalidade | Situação | Observação |
|---|---|---|
| Lista e detalhes de partidas, lidos do Firestore | ✅ | Sincronização pelo backend a cada 5 minutos; o app não chama o provedor |
| Escudos dos times (PNG e SVG) | ✅ | URL do provedor; ícone padrão sem imagem; partidas já finalizadas não ganham escudo na sincronização |
| Créditos "Dados fornecidos por football-data.org" | ✅ | Tela de créditos |

## Desafios e BetCoins

| Funcionalidade | Situação | Observação |
|---|---|---|
| Criar desafio (5 primeiras partidas, "Mostrar mais") | ✅ | Reserva de BetCoins do criador |
| Aceitar com palpite diferente, recusar, cancelar, expirar | ✅ | Backend transacional e idempotente |
| Estado dos desafios na Home | ✅ | Enviados, recebidos, em aberto e finalizados |
| Liquidação pelo resultado oficial | ✅ | Saldos 1.100 e 900 observados nas contas de teste; sem registro formal da jornada |
| Resultado oficial e efeito nos BetCoins nos finalizados | ✅ | |
| Cancelamento por tempo só com sincronização viva (T-01) | 🧪 | Testado em emulador; publicado no `syncMatches` |
| Bônus de recuperação (RF-020) | 🧪 | Ação na Home com horário do próximo resgate |
| Extrato de BetCoins (RF-019) | 🧪 | Exige o índice de `betCoinTransactions` publicado |
| Histórico completo paginado (RF-021) | 🧪 | "Ver todos" na seção de finalizados; usa índice existente |
| Ranking | ➖ | Fora do MVP |

## Infraestrutura

| Item | Situação |
|---|---|
| Firebase (Auth, Firestore, Functions) | ✅ Security Rules, índices e Functions publicados em `southamerica-east1`; as funções novas dependem de deploy |
| Testes automatizados | ✅ ver a quarta auditoria |
| Backup e recuperação do Firestore | ⏳ backup pontual desligado em 01/11 (não reverificado) |
| Assinatura de release, `LICENSE`, App Check, Crashlytics | ⏳ ver a quarta auditoria |
