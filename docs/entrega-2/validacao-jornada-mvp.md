# Validação e Integração da Jornada Completa do MVP no Flutter (KAN-107)

**Código:** Branch `KAN-107` · **Rastreabilidade:** Plano Mestre v3.2 §2.1 · **Data:** 19/11/2026  
**Componentes validados:** Mobile (Flutter), State Management (`Provider`), Roteamento (`Navigator`), Serviços do App com repositórios falsos nos testes de widget.

---

## 1. Objetivo e Escopo

Validar navegação e apresentação entre telas, estado e serviços com fakes. Estes testes não comprovam transações reais de BetCoins nem os contratos das callables.

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
   - O caminho de produção apresenta carregamento, erro com nova tentativa e vazio; não usa desafios demonstrativos como fallback.
4. **Navegação com fakes de duas contas (UIDs opacos `a7Qz2r8P0xLm` e `b9Wx4k6J1nTs`):**
   - Criação de desafio por Ana Lima contra Bia Rocha para aposta em partida válida.
   - Atualização simulada no fake da carteira do criador (Ana passa de 1000 disponíveis para 900 disponíveis e 100 reservadas).
   - Logout seguro de Ana e login de Bia Rocha.
   - Exibição de destaque do desafio recebido aguardando resposta na Home de Bia.
   - Aceite do desafio por Bia via `ModalAceitarDesafio`, validação de palpite oposto obrigatório (RN-PRD-003) e reserva dos BetCoins de Bia (900 disponíveis, 100 reservadas).
   - Evolução do desafio para `ACCEPTED` e movimentação para a seção "DESAFIOS EM ABERTO".
   - Simulação de encerramento pelo fake e verificação da seção "DESAFIOS FINALIZADOS". O teste não verifica os saldos finais de 1100/900.
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

### 3.1. Testes de widget: navegação com fakes (`test/jornada_completa_mvp_test.dart`)

Executar com `flutter test test/jornada_completa_mvp_test.dart`.

`_FakeChallengeRepository` simula criação, reserva e liquidação; os resultados não constituem evidência de integridade financeira do backend. Essa integridade é coberta pelos testes reais de transações em `functions/test/`.

**Cenários validados no teste de jornada:**
1. **Jornada Completa com Duas Contas (Ana Lima e Bia Rocha):**
   - Login de Ana Lima (`a7Qz2r8P0xLm`). Home renderiza saudação `"Olá, Ana Lima"` e saldo de 1000 BetCoins.
   - Navegação: Home → Perfil → Meus Amigos. Exibe Bia Rocha (`@BiaR`) como amiga aceita, sem vazamento de saldo ou dados internos.
   - Integração: Toque em `DESAFIAR` no card de Bia abre `CriarDesafioScreen` com `Bia Rocha` e `b9Wx4k6J1nTs` pré-selecionados.
   - Seleção de valor (100 BetCoins) e envio do desafio. Carteira de Ana passa para 900 disponíveis e 100 reservadas.
   - Retorno à Home exibe desafio em `DESAFIOS ENVIADOS` ("Aguardando Bia Rocha").
   - Logout de Ana com confirmação em diálogo. Retorno imediato ao `LoginPage`.
   - Login de Bia Rocha (`b9Wx4k6J1nTs`). Home de Bia renderiza `"Olá, Bia Rocha"`, saldo de 1000 BetCoins e destaca `DESAFIOS RECEBIDOS`.
   - Bia clica em `RESPONDER`, abre `ModalAceitarDesafio`, seleciona o palpite oposto permitido ("Vitória Visitante") e confirma.
   - Carteira de Bia passa para 900 disponíveis e 100 reservadas. Desafio transiciona para `ACCEPTED` e aparece em `DESAFIOS EM ABERTO`.
   - O fake finaliza a partida e altera as carteiras internamente; a asserção da UI só verifica `DESAFIOS FINALIZADOS`, não os saldos finais.
   - Navegação até `TelaInformacoesCreditos` confirma texto `"Dados fornecidos por football-data.org"`.
2. **Tratamento Honesto de Estados de Erro, Vazio e Offline:**
   - Lista de amigos vazia exibe `'Nenhum amigo adicionado'` e botão de ação.
   - Falha de comunicação no repositório de amizades exibe mensagem honesta `'Falha ao carregar amigos'` sem gerar mocks.
   - Modo offline no perfil renderiza `AvisoSemConexao` e exibe dados salvos sem permitir escritas inseguras.

### 3.2. Teste de Integração contra Emuladores Firebase (`integration_test/jornada_mvp_emulator_test.dart`)

- Usa contas exclusivas do seed (`uidAnaJornada` e `uidBiaJornada`) contra Auth (`9099`), Firestore (`8080`) e Functions (`5001`); não compartilha perfis com os testes de edição de nome.
- Verifica login, leitura do próprio perfil/carteira e `listarAmigosAceitos` via callable `getFriends`. Não cria, aceita nem liquida desafios.
- `integration_test/partidas_emulator_test.dart` cobre o repositório real de partidas com temporada passada e futura semeada e leitura offline.
- Estes testes FlutterFire não foram executados nesta correção: não havia dispositivo/emulador Android disponível. Consulte `integration_test/README.md` e use `flock /tmp/betfriends-emulator.lock`.
- Valida que as Security Rules do Firestore impedem rigorosamente leitura de documentos `users/{uid}` alheios (retorna `permission-denied`).
- Valida que a sessão encerrada bloqueia chamadas não autenticadas (`unauthenticated`).

### 3.3. Análise Estática e Suíte Global

A linha de base da auditoria era `flutter analyze` sem avisos e 339 testes unitários/widget aprovados. A quantidade muda com as regressões adicionadas; executar `flutter analyze` e `flutter test` na revisão atual. O teste de horário também deve passar com `TZ=Asia/Tokyo flutter test test/partidas_futuras_test.dart`.

Verificação desta correção: `flutter analyze` sem avisos, `flutter test` com **349 testes aprovados**, e os **8 testes de partidas futuras aprovados em Asia/Tokyo**. Integrações nativas: **não executadas (sem Android)**.

---

## 4. Mapeamento de Dependências e Limitações

| Domínio | KANs Relacionados | Status / Observações |
|---|---|---|
| **Amizades** | KAN-33 a KAN-41 | Implementado e validado. Telas consom `FriendshipService` e `UserSearchService`. |
| **Desafios** | KAN-55 a KAN-68 | Navegação e apresentação validadas com fakes. Transações reais cobertas separadamente em `functions/test/`. |
| **Carteira / Extrato** | KAN-69 a KAN-71 | Implementado e validado. Leitura de `saldoTotal` e `saldoReservado` com cálculo estrito de `saldoDisponivel`. Ledger detalhado mantido pelo backend. |
| **Histórico** | KAN-88 a KAN-91 | Tela de histórico completo acessível por “Ver todos” nos desafios finalizados da Home, com paginação por “Carregar mais”, estados de carregamento, vazio e erro com nova tentativa, reutilizando os resultados e detalhes da Home (RF-021). |
| **Partidas** | KAN-42, KAN-105 | Consumo via Firestore com rate limit guard e TTL e polling de pelo menos 5 minutos, pausado em segundo plano e sem consultas concorrentes. |
| **Apresentação Acadêmica** | KAN-97, KAN-98 | Fora do escopo desta tarefa técnica; escopo mantido estritamente na validação do código do MVP. |

---

## 5. Conclusão

A suíte de widget cobre navegação, apresentação e estados com fakes; não garante por si só integridade dos saldos, ausência de vazamento de memória ou comportamento do backend real. Reserva, liberação e liquidação devem ser avaliadas nos testes de `functions/test/`; privacidade e consultas reais têm cobertura própria de regras/emuladores.

Nesta correção foram adicionados handlers globais de erro e saída de diagnóstico em debug, sem Crashlytics: coleta persistente/remota em release continua inexistente. O logout chama `terminate()` antes de `clearPersistence()` e o backup Android foi desabilitado; limpeza nativa e novo login após logout precisam de verificação em Android. Controles antes baseados em `GestureDetector` usam botões/`InkWell`, com alvos de 48dp e texto secundário mais claro. Fachadas sem referências (`firestore_service.dart` e `firebase_options.dart`) foram removidas após consulta ao LSP; o histórico paginado agora possui tela, como explicitado acima.
