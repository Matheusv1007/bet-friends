# Validação e Integração da Jornada Completa do MVP no Flutter (KAN-107)

**Código:** Branch `KAN-107` · **Rastreabilidade:** Plano Mestre v3.2 §2.1 · **Data:** 19/11/2026  
**Componentes validados:** Mobile (Flutter), State Management (`Provider`), Roteamento (`Navigator`), Serviços e Repositórios do App.

---

## 1. Objetivo e Escopo

Validar a integração real entre telas, estado e serviços do MVP do BetFriends, garantindo a coesão de toda a experiência do usuário sem acrescentar recursos fora do Plano Mestre v3.2.

### Escopo Coberto
1. **Navegação Completa e Sem Crash:**
   - Fluxo contínuo entre `AuthGate` / `LoginPage` / `CadastroPage`, `Homepage`, `PerfilScreen`, `TelaListaAmigos`, `TelaBuscarUsuarios`, `TelaComunicacoesAmizade`, `CriarDesafioScreen`, `ModalAceitarDesafio` e `TelaInformacoesCreditos`.
   - Remoção de duplicações de pilha, garantindo retornos limpos via `Navigator.pop()` e travamento de telas autenticadas após logout.
2. **Integração de Entradas/Saídas:**
   - Conexão entre a lista de amigos aceitos e a tela de criação de desafio: ao clicar em `DESAFIAR` no card de um amigo em `TelaListaAmigos`, o amigo é pré-selecionado automaticamente (`preSelectedFriendId` e `preSelectedFriendName`) em `CriarDesafioScreen`.
   - Propagação limpa de serviços (`FriendshipService`, `ChallengeService`, `UserSearchService`, `UserProfileService`) através do `App` (`MultiProvider`), permitindo injeção controlada de repositórios/fakes em testes e conexão direta aos serviços reais em produção.
3. **Segregação de Dados e Privacidade (RN-PROF-002, RN-FRD-001, RN-AUTH-006):**
   - Garantia de que a UI exibe apenas os dados do usuário autenticado no momento.
   - Amigos aceitos exibem exclusivamente nome de exibição e `@username`. Nenhum e-mail, saldo detalhado de BetCoins, transação ou dado interno é exposto a terceiros.
   - Nenhum dado demonstrativo ou mock é apresentado como real (crachás demonstrativos exibidos honestamente apenas quando o módulo de desafios não estiver carregado).
4. **Jornada Ponta a Ponta com Duas Contas de Demonstração (`uidAna` e `uidBia`):**
   - Criação de desafio por Ana Lima contra Bia Rocha para aposta em partida válida.
   - Reserva atômica de BetCoins do criador (Ana passa de 1000 disponíveis para 900 disponíveis e 100 reservadas).
   - Logout seguro de Ana e login de Bia Rocha.
   - Exibição de destaque do desafio recebido aguardando resposta na Home de Bia.
   - Aceite do desafio por Bia via `ModalAceitarDesafio`, validação de palpite oposto obrigatório (RN-PRD-003) e reserva dos BetCoins de Bia (900 disponíveis, 100 reservadas).
   - Evolução do desafio para `ACCEPTED` e movimentação para a seção "DESAFIOS EM ABERTO".
   - Simulação de encerramento de partida: resolução com vitória de Ana (saldo de Ana atualizado para 1100 disponíveis e Bia para 900 disponíveis), com transição para "DESAFIOS FINALIZADOS".
5. **Estados Carregando, Vazio, Erro e Offline/Cache:**
   - Amigos vazios exibem orientações honestas com atalho para busca de amigos.
   - Erros de rede/serviço (`unavailable`) exibem feedback amigável sem quebrar o app e sem inventar dados simulados.
   - Perfil offline exibe aviso visual `AvisoSemConexao`, exibe dados em cache e bloqueia edições sem conexão.
6. **Informações e Créditos Obrigatórios (RNF-011, RNF-012, D-015):**
   - Tela `TelaInformacoesCreditos` acessível via `PerfilScreen` e menu da conta na Home, contendo o texto exato: `"Dados fornecidos por football-data.org"`.

---

## 2. Matriz de Rotas e Navegação

| Origem | Destino | Gatilho / Widget | Parâmetros Integrados |
|---|---|---|---|
| `AuthGate` | `Homepage` | Sessão ativa detectada | Sessão corrente do `AuthProvider` |
| `AuthGate` | `LoginPage` | Nenhuma sessão ativa | N/A |
| `LoginPage` | `CadastroPage` | Toque em "Criar conta" | Submissão e retorno automático |
| `Homepage` | `PerfilScreen` | BottomNav (índice 2) ou Menu da Conta | Consome `UserProfileService` via `Provider` |
| `Homepage` | `CriarDesafioScreen` | BottomNav (índice 1) ou card vazio | `challengeService` injetado |
| `Homepage` | `ModalAceitarDesafio` | Toque em "RESPONDER" no card de pendência | `ChallengeModel`, `nomeCriador`, `challengeService` |
| `Homepage` | `LoginPage` | Menu da conta -> "Sair da conta" | Confirmação em diálogo; limpa sessão no `AuthGate` |
| `PerfilScreen` | `TelaListaAmigos` | Botão `perfil_meus_amigos` | `friendshipService` injetado |
| `PerfilScreen` | `TelaBuscarUsuarios` | Botão `perfil_buscar_usuarios` | `friendshipService`, `userSearchService` injetados |
| `PerfilScreen` | `TelaComunicacoesAmizade` | Botão `perfil_solicitacoes_amizade` | `friendshipService` injetado |
| `PerfilScreen` | `TelaInformacoesCreditos` | Botão `perfil_informacoes_creditos` | Texto obrigatório RNF-011 |
| `TelaListaAmigos`| `CriarDesafioScreen` | Botão `btn_desafiar_amigo_{uid}` | `preSelectedFriendId`, `preSelectedFriendName`, `challengeService` |
| `TelaListaAmigos`| `TelaBuscarUsuarios` | Botão AppBar ou card vazio | `friendshipService`, `searchService` injetados |
| `TelaListaAmigos`| `TelaComunicacoesAmizade` | Botão AppBar de notificações | `friendshipService` injetado |

---

## 3. Evidências de Testes Automatizados

### 3.1. Testes de Integração da Jornada Completa (`test/jornada_completa_mvp_test.dart`)

```
00:00 +0: loading test/jornada_completa_mvp_test.dart
00:00 +0: Jornada completa e integrada do MVP com duas contas (Ana e Bia), criação/aceite de desafio, reserva de BetCoins, resolução e navegação sem crash
00:02 +1: Tratamento honesto de estados de erro, vazio e offline sem dados falsos
00:02 +2: All tests passed!
```

**Cenários validados no teste de jornada:**
1. **Jornada Completa com Duas Contas (Ana Lima e Bia Rocha):**
   - Login de Ana Lima (`uidAna`). Home renderiza saudação `"Olá, Ana Lima"` e saldo de 1000 BetCoins.
   - Navegação: Home → Perfil → Meus Amigos. Exibe Bia Rocha (`@BiaR`) como amiga aceita, sem vazamento de saldo ou dados internos.
   - Integração: Toque em `DESAFIAR` no card de Bia abre `CriarDesafioScreen` com `Bia Rocha` e `uidBia` pré-selecionados.
   - Seleção de valor (100 BetCoins) e envio do desafio. Carteira de Ana passa para 900 disponíveis e 100 reservadas.
   - Retorno à Home exibe desafio em `DESAFIOS ENVIADOS` ("Aguardando uidBia").
   - Logout de Ana com confirmação em diálogo. Retorno imediato ao `LoginPage`.
   - Login de Bia Rocha (`uidBia`). Home de Bia renderiza `"Olá, Bia Rocha"`, saldo de 1000 BetCoins e destaca `DESAFIOS RECEBIDOS`.
   - Bia clica em `RESPONDER`, abre `ModalAceitarDesafio`, seleciona o palpite oposto permitido ("Vitória Visitante") e confirma.
   - Carteira de Bia passa para 900 disponíveis e 100 reservadas. Desafio transiciona para `ACCEPTED` e aparece em `DESAFIOS EM ABERTO`.
   - Simulação de finalização da partida com vitória de Ana: carteira de Ana recebe o prêmio (1100 BetCoins) e Bia tem a reserva consumida (900 BetCoins). Desafio passa para `DESAFIOS FINALIZADOS`.
   - Navegação até `TelaInformacoesCreditos` confirma texto `"Dados fornecidos por football-data.org"`.
2. **Tratamento Honesto de Estados de Erro, Vazio e Offline:**
   - Lista de amigos vazia exibe `'Nenhum amigo adicionado'` e botão de ação.
   - Falha de comunicação no repositório de amizades exibe mensagem honesta `'Falha ao carregar amigos'` sem gerar mocks.
   - Modo offline no perfil renderiza `AvisoSemConexao` e exibe dados salvos sem permitir escritas inseguras.

### 3.2. Teste de Integração contra Emuladores Firebase (`integration_test/jornada_mvp_emulator_test.dart`)

- Executa com as contas controladas criadas por `integration_test/support/seed_emulators.mjs` (`uidAna` e `uidBia`) contra o Auth Emulator (`9099`) e Firestore Emulator (`8080`).
- Valida que as Security Rules do Firestore impedem rigorosamente leitura de documentos `users/{uid}` alheios (retorna `permission-denied`).
- Valida que a sessão encerrada bloqueia chamadas não autenticadas (`unauthenticated`).

### 3.3. Análise Estática e Suíte Global

- `flutter analyze`: **0 erros, 0 warnings** (No issues found).
- `flutter test`: **339/339 testes aprovados** (100% de sucesso).

---

## 4. Mapeamento de Dependências e Limitações

| Domínio | KANs Relacionados | Status / Observações |
|---|---|---|
| **Amizades** | KAN-33 a KAN-41 | Implementado e validado. Telas consom `FriendshipService` e `UserSearchService`. |
| **Desafios** | KAN-55 a KAN-68 | Implementado e validado no Flutter. Criação, aceite, recusa, cancelamento e resumo integrados. |
| **Carteira / Extrato** | KAN-69 a KAN-71 | Implementado e validado. Leitura de `saldoTotal` e `saldoReservado` com cálculo estrito de `saldoDisponivel`. Ledger detalhado mantido pelo backend. |
| **Histórico** | KAN-88 a KAN-91 | Implementado e testado com paginação e cursor no emulador. |
| **Partidas** | KAN-42, KAN-105 | Consumo via Firestore com rate limit guard e polling ajustado para 60s. |
| **Apresentação Acadêmica** | KAN-97, KAN-98 | Fora do escopo desta tarefa técnica; escopo mantido estritamente na validação do código do MVP. |

---

## 5. Conclusão

A jornada completa do MVP encontra-se plenamente integrada, estável e validada. A navegação entre todos os módulos do Plano Mestre v3.2 ocorre sem vazamento de memória ou duplicidade de pilhas, e a integridade dos saldos e privacidade dos usuários está garantida tanto em testes unitários/widget quanto em integração com os emuladores Firebase.
