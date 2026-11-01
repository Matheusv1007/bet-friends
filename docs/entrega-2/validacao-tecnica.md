# Validação técnica — Segunda Entrega

## Testes automatizados (01/11/2026)

**Código:** `805eea8` · **Ambiente:** Arch Linux, Node 22.23.4, JDK 21, `emulator-5554`, emuladores no projeto `demo-betfriends`. Nenhum teste automatizado usou o Firebase de produção.

| Verificação | Resultado |
|---|---|
| `flutter analyze` | **0 erros**; 7 avisos já conhecidos (2 variáveis sem uso em teste e 5 nomes de arquivo) |
| `flutter test` | ✅ **176/176** |
| `npm test` em `functions/` | ✅ **118/118** testes puros |
| Backend + Security Rules no Firestore Emulator | ✅ **365/365** |
| `integration_test/` no Android (Auth, Firestore e Functions Emulator) | ✅ **54/54**, em 7 arquivos |

## Validação no Firebase real (01/11/2026)

**Código:** `805eea8` · **Projeto:** `betfriends-unirv-2026`, com três contas de teste `qa_*` e e-mails fictícios. Cada teste foi autorizado separadamente, com conferência por leitura antes e depois. Senhas digitadas manualmente e não registradas.

| Teste | O que validou | Resultado |
|---|---|---|
| R-0 | `createUserProfile` sem token | ✅ HTTP 401; nada gravado |
| R-1 | Cadastro completo pelo app | ✅ Perfil, reserva e um `INITIAL_BALANCE` +1000 na mesma transação; 1000 / 0 |
| R-2 | Username de outra conta em outra caixa; conclusão com outro | ✅ Recusado (409), sem documentos; depois concluído |
| R-3 | E-mail repetido | ✅ Mensagem de e-mail cadastrado; nenhuma conta nova |
| R-4 | Senha de 5 caracteres e senhas diferentes | ✅ Bloqueio no app; nenhuma chamada à função |
| R-5 | Cadastro sem rede; conclusão com rede | ✅ Mensagem de conexão, nada gravado; depois uma carteira só |
| R-6 | 5 chamadas simultâneas com carteira já criada | ✅ Todas `criado: false`; documentos sem regravação |
| R-7 | Perfil, edição do nome, logout e novo login; edição em modo avião | ✅ Nome persiste; só `displayName` e `updatedAt` mudam; edição offline bloqueada, sem escrita pendente |
| R-8 parcial | Ler o próprio perfil; ler perfil de outra conta; listar `users` | ✅ 200; 403 `PERMISSION_DENIED`; 403 `PERMISSION_DENIED` |
| R-9 | Fechamento | ✅ 3 perfis, 3 reservas, 3 lançamentos; saldos 1000 / 0; sem órfãos; sem erro nos logs de `createUserProfile` |

**Não comprovado em produção:**

| Item | Situação |
|---|---|
| Negação de escrita (saldo, `usernames`, lançamento) | A execução real não foi autorizada, porque o banco não tem PITR nem backup. No emulador, com as regras publicadas: 403 `PERMISSION_DENIED`. Só essa resposta comprova bloqueio; `FAILED_PRECONDITION` e `NOT_FOUND` não comprovam |
| Disputa simultânea na primeira criação da carteira | Só em emulador |
| Retomada do cadastro pelo Perfil, depois de reabrir o app | Código e testes com emuladores |
| Perda de conexão com o diálogo de edição aberto | Só em emulador |
| `claimRecoveryBonus`, reserva e liquidação com dados reais | Sem fluxo no app; nenhum desafio real existe |

**Limites:** a busca por token, senha e e-mail nos logs cobriu `createUserProfile`, não o Firebase Auth nem outras funções. Duas contas anteriores do Auth foram conferidas só por contagem. As contas de teste permanecem no projeto, e a conta B não deve ser usada: a primeira senha digitada nela apareceu em uma captura de preparação, antes do envio.

**Situação do projeto real (01/11, leitura):** Blaze ativo; `systemPing`, `createUserProfile`, `claimRecoveryBonus` e `syncMatches` ativas; job da `syncMatches` a cada 5 minutos; 380 documentos em `matches`; regras idênticas às do repositório; PITR desligado e sem backups.

As seções abaixo são o histórico anterior e **refletem o estado das suas datas**.

## Testes automatizados (29/10/2026)

**Código:** `qas` em `5ed4796` (merge do PR #35) · **Ambiente:** cópia isolada do repositório (`git archive`), Arch Linux, Flutter 3.47.5, Node 26, Firestore Emulator 1.22.0 com JDK 21, projeto `demo-betfriends`. Nenhum teste usou o Firebase de produção.

| Verificação | Resultado |
|---|---|
| `flutter analyze` | **0 erros**, 2 warnings, 5 infos, todos já existentes: variáveis não usadas em `test/partidas_provider_test.dart` e nomes de arquivo fora do padrão |
| `flutter test` | ✅ **128/128** |
| `npm test` em `functions/` | ✅ **58/58** testes puros; as suítes de emulador são puladas fora do emulador |
| Backend no Firestore Emulator | ✅ **131/131** (58 puros + 73 no emulador: carteira inicial 11, cadastro e username 9, desfecho 15, `Match` 7, reserva e liberação 11, saldos 7, ledger 13) |
| Security Rules no Firestore Emulator | ✅ **77/77** |
| `git diff --check` | ✅ |

### Não executado em 29/10

| Verificação | Motivo | Última evidência |
|---|---|---|
| `integration_test/` no Android contra os emuladores | Nenhum dispositivo Android ativo | ✅ **33/33** em 28/10 (17 perfil, 5 tela de Perfil, 3 edição de nome, 8 modo offline). Desde então o app só ganhou uma constante (`CallableNames.createUserProfile`) |
| Chamada da `createUserProfile` pelo Functions Emulator (HTTP) | Não existe suíte para isso; a Callable foi testada só pela execução direta da função no emulador do Firestore | — |
| Deploy das Functions e das Security Rules | Fora do escopo; exige autorização da equipe | Em 28/10, a Cloud Functions API estava desabilitada no projeto (HTTP 403). As Security Rules foram publicadas depois, em 29/10 (ver [Publicação das Security Rules](#publicação-das-security-rules-29102026)); as Functions continuam sem deploy |

Os PRs #26 a #35 foram integrados sem descrição e sem revisão formal registrada. Esta execução é a primeira registrada da suíte completa do backend depois deles.

## Publicação das Security Rules (29/10/2026)

**Código:** `qas` em `74a9bcf` (merge do PR #40) · **Ambiente:** Node 22.23.4 isolado e Firebase CLI 15.32.1 ([`docs/callable-functions.md`](../callable-functions.md) §9), Firestore Emulator com JDK 21, projeto `demo-betfriends`.

| Verificação | Resultado |
|---|---|
| `firestore.rules` | Idêntico ao da KAN-22 (`28ddc33`) |
| `npm test` em `functions/` | ✅ **67/67** |
| Backend + Security Rules no Firestore Emulator | ✅ **226/226** (149 do backend + 77 das rules) |
| `deploy --only firestore:rules --project betfriends-unirv-2026` | ✅ Regras compiladas e publicadas; a versão publicada é idêntica ao arquivo do repositório (SHA-256 conferido) |

Situação do projeto real depois da publicação (auditoria somente leitura):

- **Plano Spark** (sem faturamento); a Cloud Functions API não está ativa e **nenhuma Cloud Function está publicada**.
- Firestore `(default)` em `southamerica-east1`, sem documentos e sem índices compostos.
- Authentication com e-mail e senha ativo.

Pendências para publicar as Functions: decisão sobre o plano Blaze (com alerta de orçamento); permissão de deploy, porque a conta usada na auditoria não pode definir a política IAM do Cloud Run (`run.services.setIamPolicy`), necessária para liberar a invocação das Callables, e o Proprietário deve fazer o deploy ou conceder esse papel; depois, o deploy das Functions e um teste em produção.

## Ensaio no emulador (28/10/2026)

**Código:** branch `feature/KAN-104-segunda-entrega`, a partir de `qas` em `ccfb8e1` (merge do PR #14). **Esse ensaio é anterior** ao Perfil, à edição de nome, ao modo offline e à limpeza da Home (PRs #19 a #25), e **não foi refeito** com o código atual.

| Verificação | Resultado |
|---|---|
| `flutter doctor` | Flutter ✔ · Android toolchain ✔ (SDK 36.0.0) · Linux toolchain ✔ · Network ✔ · Chrome ✘ (irrelevante para Android) |
| `flutter test` (código da época) | ✅ 65/65 |
| `flutter build apk --debug` | ✅ Compilou em ~61 s. Aviso conhecido: plugins `cloud_functions`, `firebase_auth` e `firebase_core` ainda usam o Kotlin Gradle Plugin |
| Instalação no emulador | ✅ `adb install -r` no AVD `Pixel_10_Pro` (Android 17) |
| Abertura do app | ✅ Abre no Login, sem crash. Não havia sessão salva no emulador |
| Login com campos vazios | ✅ Mostra "Preencha o e-mail e a senha." |
| Login → "Criar conta" → Cadastro | ✅ Tela "Criar Conta" exibida |
| Voltar no Cadastro | ✅ Retorna ao Login |
| Voltar no Login | ✅ Sai para o launcher, sem tela duplicada |
| Erros no logcat | Nenhum `FATAL EXCEPTION` nem `E/flutter` durante os passos acima |

### Ensaio com login (28/10, `flutter run` em debug no emulador)

Login feito **manualmente pelo usuário**; nenhuma credencial foi lida ou registrada. Navegação por `adb shell input`, verificação por `uiautomator dump`.

| Passo | Resultado |
|---|---|
| Login com conta válida | ✅ Home exibida |
| Home com partidas reais | ✅ 3 próximos jogos do dia (ex.: Bragantino × Chapecoense, Fluminense × Internacional, Santos × Palmeiras), com escudos |
| Puxar para atualizar | ✅ Lista mantida, sem aviso de erro |
| "MAIS PARTIDAS" | ✅ Lista completa, com partidas finalizadas e botão "MOSTRAR MENOS" |
| "Desafiar" → Criar Desafio | ✅ 10 partidas elegíveis (hoje, amanhã e 30/10) |
| Selecionar partida + ENVIAR DESAFIO | ✅ "Modo demonstrativo: nenhum desafio foi salvo no banco." e retorno à Home |
| Avatar → "Sair da conta" → diálogo "Sair da conta?" → Sair | ✅ Volta ao Login |
| Voltar no Login após o logout | ✅ Vai para o launcher; não retorna à Home |
| Reabrir o app após o logout | ✅ Abre no Login: a sessão foi encerrada no Firebase, não só na tela |
| Novo login manual → fechar o app (`am force-stop`) → reabrir | ✅ Abre **direto na Home**, sem pedir login; Home já presente na primeira amostra (≈ 1 s após o início, `TotalTime` 1222 ms) |
| Erros no log do `flutter run` e no logcat | Nenhum `E/flutter`, `FATAL` ou `Exception` em todo o ensaio |

O `flutter run` encerrou com "Lost connection to device" ao fechar o app à força, o que é esperado. A reabertura usou o APK debug já instalado.

**Observação visual (não corrigida):** o escudo da Chapecoense aparece como um quadrado branco vazio na Home, enquanto os outros escudos aparecem normalmente. A causa não foi investigada. Não afeta a navegação; o uso de escudos da API já está registrado como pendência (RNF-012, KAN-54).

## Pendente (exige ação manual)

| # | Verificação | Por que não foi feita | Como fazer |
|---|---|---|---|
| P-1 | Refazer o roteiro completo da demo em sequência | Partes foram exercitadas em 01/11, mas não o roteiro inteiro | `flutter run -d emulator-5554` a partir da branch apresentada, seguindo [roteiro-demonstracao.md](roteiro-demonstracao.md) |
| P-3 | Teste em aparelho físico | Nenhum aparelho conectado | `flutter run -d <id>` com depuração USB |
| P-4 | Build **release** do código atual | Não refeito; o último build release é de 19/10 | `flutter build apk --release`, só para uso local (ver aviso abaixo) |
| P-5 | Gravação do vídeo de contingência | Planejada para 03 a 05/11 | `scrcpy --record demo.mp4` ou gravador do emulador |
| P-6 | Erro real de limite da API (HTTP 429) e abertura sem internet | Não provocados, para não consumir a cota | Opcional; coberto por testes automatizados |

## Aviso sobre builds

O APK contém hoje o token da football-data.org embutido no código. **Use os APKs apenas no emulador ou no aparelho da equipe. Não publique o APK no Classroom, no GitHub Releases nem em grupos.** A correção depende da troca do token (KAN-102) e da migração das chamadas para o backend (KAN-44).
