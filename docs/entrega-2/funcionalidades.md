# Funcionalidades — situação real na Segunda Entrega

Legenda: ✅ real e testado · 🟡 parcial · 🎭 demonstrativo (interface sem efeito real) · ⏳ pendente

## Conta e sessão

| Funcionalidade | Situação | Observação |
|---|---|---|
| Login com e-mail e senha | ✅ | Firebase Authentication; mensagens de erro traduzidas (KAN-26) |
| Restauração de sessão | ✅ | `AuthGate` abre direto na Home se já houver sessão (KAN-27) |
| Logout | ✅ | Menu do avatar, com confirmação; Voltar não retorna às telas protegidas (KAN-27) |
| Cadastro | 🎭 | Formulário sem ação: "CADASTRAR" só volta ao Login (KAN-25) |
| Perfil vinculado ao UID | 🟡 | Modelo, repositório e serviço testados; sem gravação real até as regras do Firestore (KAN-32) |
| Tela de perfil | ⏳ | Aba "Perfil" sem destino (KAN-28) |

## Partidas (API football-data.org)

| Funcionalidade | Situação | Observação |
|---|---|---|
| Listar partidas do Brasileirão | ✅ | Ao vivo, próximas e finalizadas recentes (BSA) |
| Estados de carregamento, erro e vazio | ✅ | Com "Tentar novamente" e mensagens amigáveis |
| Puxar para atualizar e atualização a cada 30 s | ✅ | Mantém os dados anteriores com aviso se a atualização falhar |
| Sincronização pelo backend e cache no Firestore | ⏳ | Hoje o app chama a API diretamente (KAN-44 a KAN-50) |
| Detalhes da partida | ⏳ | KAN-43 |
| Créditos "Data provided by football-data.org" | ⏳ | Só no README por enquanto (KAN-54) |

## Desafios e BetCoins

| Funcionalidade | Situação | Observação |
|---|---|---|
| Tela Criar Desafio | 🟡 / 🎭 | Partidas reais e elegíveis (sem finalizadas, canceladas ou adiadas); saldo e amigos fixos; envio sem gravação, com aviso "Modo demonstrativo" |
| Desafios Ativos na Home | 🎭 | Exemplos fixos |
| Saldo exibido ("1.500 fichas") | 🎭 | Valor fixo; a regra oficial é saldo inicial de 1.000 BetCoins |
| Amizades, aceite e recusa, estados do desafio | ⏳ | KAN-33 a KAN-41 e KAN-55 a KAN-68 |
| Reserva, premiação, extrato e recuperação de BetCoins | ⏳ | KAN-69 a KAN-81 |
| Liquidação automática e histórico | ⏳ | KAN-82 a KAN-91 |
| Ranking | — | Fora do MVP; a aba existe, mas não abre tela |

## Infraestrutura

| Item | Situação |
|---|---|
| Firebase (Auth, Firestore, configuração Android) | ✅ configurado |
| Estrutura de Callable Functions com testes (7) | 🟡 pronta, **não implantada** |
| Regras do Firestore | 🟡 bloqueiam todo acesso até a KAN-22 |
| Testes automatizados Flutter | ✅ 65 |
