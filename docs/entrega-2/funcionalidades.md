# Funcionalidades — situação real na Segunda Entrega

Atualizado em 01/11/2026 (base: `qas` em `805eea8`).

Legenda: ✅ validado no app com o Firebase real · ☁️ publicado no projeto real, sem uso pelo app · 🧪 implementado e testado só em emulador · 🟡 parcial · 🎭 demonstrativo (interface sem efeito real) · ⏳ pendente

## Conta e sessão

| Funcionalidade | Situação | Observação |
|---|---|---|
| Login com e-mail e senha | ✅ | Firebase Authentication; mensagens de erro traduzidas (KAN-26) |
| Restauração de sessão | ✅ | `AuthGate` abre direto na Home se já houver sessão (KAN-27); último ensaio específico em 28/10 |
| Logout | ✅ | Menu do avatar, com confirmação; volta ao Login (KAN-27) |
| Cadastro pela tela | ✅ | Cria conta, perfil, username único e carteira (KAN-25). Bloqueia senha curta, senhas diferentes, e-mail e username repetidos |
| Cadastro sem rede | ✅ | Mensagem de conexão, nada gravado; concluir com rede cria uma carteira só |
| Retomar cadastro pelo Perfil, depois de reabrir o app | 🧪 | Testado com emuladores; não exercitado no Firebase real |
| Perfil vinculado ao UID | ✅ | Leitura pelo dono; leitura de terceiros e listagem negadas no real (KAN-32) |
| Tela de Perfil | ✅ | Nome e username, sem e-mail nem saldos (KAN-28) |
| Editar nome de exibição | ✅ | Persiste depois de novo login; só `displayName` e `updatedAt` mudam (KAN-29) |
| Comportamento sem conexão | ✅ | Dados salvos com aviso; edição e cadastro bloqueados, sem escrita pendente (KAN-24). Perda de conexão com o diálogo aberto só foi testada com emuladores |

## Home

| Funcionalidade | Situação | Observação |
|---|---|---|
| Barra inferior Home / Desafios / Perfil | ✅ | Ranking removido por ser pós-MVP (D-002, RN-RNK-001) |
| Saudação | ✅ | "Olá, {nome}" a partir do perfil real |
| Saldo no cabeçalho | 🟡 | Mostra "Saldo indisponível", mesmo com carteira no Firestore, até a KAN-69 |
| Desafios Ativos | 🎭 | Exemplos fixos com o selo "DEMONSTRATIVO"; "Detalhes do Desafio" sem ação |

## Partidas (API football-data.org)

| Funcionalidade | Situação | Observação |
|---|---|---|
| Listar partidas do Brasileirão | ✅ | Com chamada direta do app ao provedor |
| Estados de carregamento, erro e vazio | ✅ | Com "Tentar novamente" e mensagens amigáveis; 429 real não provocado |
| Puxar para atualizar e atualização a cada 30 s | ✅ | Mantém os dados anteriores com aviso se a atualização falhar |
| Sincronização pelo backend (`syncMatches`) | ☁️ | A cada 5 min, com o token como segredo; 380 documentos em `matches` em 01/11 |
| App lendo `matches` | ⏳ | KAN-42; pré-requisito para retirar o token do app |
| Token fora do app e troca do token | ⏳ | KAN-102; **o app ainda carrega o token** |
| Detalhes da partida | ⏳ | KAN-43 |
| Créditos "Data provided by football-data.org" | ⏳ | Só no README por enquanto (KAN-54) |

## Desafios e BetCoins

| Funcionalidade | Situação | Observação |
|---|---|---|
| Carteira inicial | ✅ | 1.000 BetCoins e um `INITIAL_BALANCE` por perfil, em uma única transação (KAN-72) |
| Idempotência da criação | ✅ / 🧪 | 5 chamadas simultâneas com carteira existente, sem alteração, no real; disputa na primeira criação só em emulador |
| Negação de escrita pelo cliente (saldo, `usernames`, lançamentos) | 🧪 | Com as mesmas regras publicadas; **não comprovada em produção** |
| Invariantes de saldo e transações auditáveis | 🧪 | KAN-73, KAN-79; a carteira inicial as usa no real, mas não há débito real |
| Reserva, liberação, premiação, perda e reembolso | 🧪 | KAN-74 a KAN-78; sem Callable nem tela |
| Liquidação pelo resultado oficial | ☁️ / 🧪 | Roda dentro da `syncMatches`; sem desafios reais, nunca liquidou em produção |
| Recuperação de BetCoins (`claimRecoveryBonus`) | ☁️ | KAN-80; testada em emulador, sem tela (KAN-71) e sem execução em produção |
| Tela Criar Desafio | 🟡 / 🎭 | Partidas reais; amigos fixos; envio sem gravação, com aviso "Modo demonstrativo" |
| Saldo na Criar Desafio ("1.500 fichas") | 🎭 | Valor fixo; a regra oficial é 1.000 BetCoins. Não apresentar como saldo real |
| Saldo e extrato na interface | ⏳ | KAN-69, KAN-70 |
| Amizades | ⏳ | KAN-33 a KAN-41 |
| Criar, aceitar e recusar desafio | ⏳ | Modelo e estados existem no backend; faltam Callables e telas |
| Histórico | ⏳ | KAN-89 |
| Ranking | — | Fora do MVP; removido da navegação |

## Infraestrutura

| Item | Situação |
|---|---|
| Firebase (Auth, Firestore, configuração Android) | ✅ configurado; plano Blaze ativo |
| Security Rules por coleção | ✅ publicadas em 29/10/2026; idênticas às do repositório em 01/11 |
| Cloud Functions | ✅ `systemPing`, `createUserProfile`, `claimRecoveryBonus` e `syncMatches` ativas em `southamerica-east1` |
| Schema do Firestore v2.0 | 🟡 documentado (`docs/firestore-schema.md`); parte das decisões ainda marcada como proposta |
| Backup e recuperação do Firestore | ⏳ PITR desligado, sem backups e sem proteção contra exclusão em 01/11 |
| Testes automatizados | ✅ Ver [validacao-tecnica.md](validacao-tecnica.md) |
