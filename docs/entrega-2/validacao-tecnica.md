# Validação técnica — Segunda Entrega

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
| Deploy das Functions e das Security Rules | Fora do escopo; exige autorização da equipe | Em 28/10, a Cloud Functions API estava desabilitada no projeto (HTTP 403). Não há registro de deploy depois disso |

Os PRs #26 a #35 foram integrados sem descrição e sem revisão formal registrada. Esta execução é a primeira registrada da suíte completa do backend depois deles.

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
| P-1 | Refazer o roteiro da demo no app atual (Home nova, aba Perfil no Firebase real) | O app mudou depois do ensaio de 28/10 | `flutter run -d emulator-5554` a partir da branch apresentada, seguindo [roteiro-demonstracao.md](roteiro-demonstracao.md) |
| P-2 | Reexecutar `integration_test/` | Nenhum dispositivo ativo em 29/10 | Comando em [`integration_test/README.md`](../../integration_test/README.md) |
| P-3 | Teste em aparelho físico | Nenhum aparelho conectado | `flutter run -d <id>` com depuração USB |
| P-4 | Build **release** do código atual | Não refeito; o último build release é de 19/10 | `flutter build apk --release`, só para uso local (ver aviso abaixo) |
| P-5 | Gravação do vídeo de contingência | Planejada para 03 a 05/11 | `scrcpy --record demo.mp4` ou gravador do emulador |
| P-6 | Erro real de limite da API (HTTP 429) e abertura sem internet | Não provocados, para não consumir a cota | Opcional; coberto por testes automatizados |

## Aviso sobre builds

O APK contém hoje o token da football-data.org embutido no código. **Use os APKs apenas no emulador ou no aparelho da equipe. Não publique o APK no Classroom, no GitHub Releases nem em grupos.** A correção depende da troca do token (KAN-102) e da migração das chamadas para o backend (KAN-44).
