# Funcionalidades — situação real na Segunda Entrega

Atualizado em 29/10/2026 (`qas` em `5ed4796`).

Legenda: ✅ funciona no app com o Firebase real · 🧪 implementado e testado só nos emuladores, sem deploy · 🟡 parcial · 🎭 demonstrativo (interface sem efeito real) · ⏳ pendente

## Conta e sessão

| Funcionalidade | Situação | Observação |
|---|---|---|
| Login com e-mail e senha | ✅ | Firebase Authentication; mensagens de erro traduzidas (KAN-26) |
| Restauração de sessão | ✅ | `AuthGate` abre direto na Home se já houver sessão (KAN-27) |
| Logout | ✅ | Menu do avatar, com confirmação; Voltar não retorna às telas protegidas (KAN-27) |
| Cadastro pela tela | 🎭 | "CADASTRAR" só volta ao Login (KAN-25, não iniciada na interface) |
| Cadastro no backend (`createUserProfile`) | 🧪 | Perfil, username único e carteira de 1.000 BetCoins numa só transação (KAN-31, KAN-72). Exportada, mas sem deploy e sem chamada pelo app |
| Perfil vinculado ao UID | 🧪 | Leitura e edição testadas no Android contra os emuladores (KAN-32). A criação ainda deve passar a usar `createUserProfile` |
| Tela de Perfil | 🧪 | Aba "Perfil" abre a tela (KAN-28). No Firebase real, as Security Rules já foram publicadas (29/10), mas ainda não há perfis: a criação depende da `createUserProfile`, sem deploy; não verificado |
| Editar nome de exibição | 🧪 | KAN-29 |
| Comportamento sem conexão | 🧪 | Escritas falham com aviso em vez de ficarem pendentes no cache (KAN-24) |

## Home

Alterações do PR #25, cobertas por 11 testes de widget (`test/home_mvp_test.dart`); ainda não vistas no emulador com o Firebase real (reensaio pendente).

| Funcionalidade | Situação | Observação |
|---|---|---|
| Barra inferior Home / Desafios / Perfil | ✅ | Ranking removido por ser pós-MVP (D-002, RN-RNK-001) |
| Saudação | ✅ | "Olá!" ou "Olá, {nome}" quando há perfil; não mostra mais nome fixo |
| Saldo no cabeçalho | ✅ | "Saldo indisponível" até existir a carteira na interface (KAN-69) |
| Desafios Ativos | 🎭 | Exemplos fixos com o selo "DEMONSTRATIVO"; "Detalhes do Desafio" sem ação |

## Partidas (API football-data.org)

| Funcionalidade | Situação | Observação |
|---|---|---|
| Listar partidas do Brasileirão | ✅ | Ao vivo, próximas e finalizadas recentes (BSA), com chamada direta do app |
| Estados de carregamento, erro e vazio | ✅ | Com "Tentar novamente" e mensagens amigáveis |
| Puxar para atualizar e atualização a cada 30 s | ✅ | Mantém os dados anteriores com aviso se a atualização falhar |
| Modelo `Match`, status e resultado no backend | 🧪 | KAN-46 a KAN-48; ainda não usados pelo app |
| Token guardado como segredo no backend | 🟡 | Estrutura pronta (KAN-21); nenhuma função usa o token e o app ainda o carrega |
| Sincronização pelo backend e cache no Firestore | ⏳ | KAN-44, KAN-45, KAN-49, KAN-50 |
| Detalhes da partida | ⏳ | KAN-43 |
| Créditos "Data provided by football-data.org" | ⏳ | Só no README por enquanto (KAN-54) |

## Desafios e BetCoins

| Funcionalidade | Situação | Observação |
|---|---|---|
| Tela Criar Desafio | 🟡 / 🎭 | Partidas reais (sem finalizadas, canceladas ou adiadas); amigos fixos; envio sem gravação, com aviso "Modo demonstrativo" |
| Saldo na Criar Desafio ("1.500 fichas") | 🎭 | Valor fixo e sem selo; a regra oficial é saldo inicial de 1.000 BetCoins. Não apresentar como saldo real |
| Invariantes de saldo e transações auditáveis | 🧪 | KAN-73, KAN-79 |
| Reserva e liberação de BetCoins | 🧪 | KAN-74, KAN-75; funções internas, sem Callable |
| Premiação, perda e reembolso em empate | 🧪 | KAN-76 a KAN-78; funções internas, ainda sem ligação com desafios |
| Saldo, extrato e recuperação na interface | ⏳ | KAN-69 a KAN-71, KAN-80, KAN-81 |
| Amizades | ⏳ | KAN-33 a KAN-41 |
| Desafios persistidos e estados | ⏳ | KAN-55 a KAN-68 (KAN-62 ainda não iniciada) |
| Liquidação automática e histórico | ⏳ | KAN-82 a KAN-91 |
| Ranking | — | Fora do MVP; removido da navegação |

## Infraestrutura

| Item | Situação |
|---|---|
| Firebase (Auth, Firestore, configuração Android) | ✅ configurado |
| Schema do Firestore v2.0 | 🟡 documentado (`docs/firestore-schema.md`); decisões ainda marcadas como proposta |
| Security Rules por coleção | ✅ **publicadas no projeto real em 29/10/2026**; 77 testes no emulador |
| Cloud Functions (`systemPing`, `createUserProfile` e módulos internos) | 🧪 131 testes; **sem deploy** (projeto no plano Spark; depende do Blaze e de permissão IAM do Proprietário) |
| Testes Flutter | ✅ 128 de unidade e widget; 33 de integração no Android (última execução em 28/10) |
