# Validação técnica — Segunda Entrega

**Data:** 28/10/2026 · **Branch:** `feature/KAN-104-segunda-entrega`, a partir de `qas` em `ccfb8e1` (merge do PR #14) · **Máquina:** Arch Linux, Flutter 3.47.5, Dart 3.13.4

## Executado

| Verificação | Resultado |
|---|---|
| `flutter doctor` | Flutter ✔ · Android toolchain ✔ (SDK 36.0.0) · Linux toolchain ✔ · Network ✔ · Chrome ✘ (irrelevante para Android) |
| `flutter analyze` | **0 erros**, 2 warnings, 5 infos, todos já existentes: variáveis não usadas em `test/partidas_provider_test.dart` e nomes de arquivo fora do padrão |
| `flutter test` | ✅ **65/65** |
| `flutter build apk --debug` | ✅ Compilou em ~61 s. Aviso conhecido: plugins `cloud_functions`, `firebase_auth` e `firebase_core` ainda usam o Kotlin Gradle Plugin |
| Instalação no emulador | ✅ `adb install -r` no AVD `Pixel_10_Pro` (Android 17) |
| Abertura do app | ✅ Abre no Login, sem crash. Não havia sessão salva no emulador |
| Login com campos vazios | ✅ Mostra "Preencha o e-mail e a senha." |
| Login → "Criar conta" → Cadastro | ✅ Tela "Criar Conta" exibida |
| Voltar no Cadastro | ✅ Retorna ao Login |
| Voltar no Login | ✅ Sai para o launcher, sem tela duplicada |
| Erros no logcat | Nenhum `FATAL EXCEPTION` nem `E/flutter` durante os passos acima |
| `git status -sb` | Sem alterações no código Dart, Android ou Firebase |

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

**Observação visual (não corrigida nesta task):** o escudo da Chapecoense aparece como um quadrado branco vazio na Home, enquanto os outros escudos aparecem normalmente. A causa não foi investigada. Não afeta a navegação; o uso de escudos da API já está registrado como pendência (RNF-012, KAN-54).

## Pendente (exige ação manual)

| # | Verificação | Por que não foi feita | Como fazer |
|---|---|---|---|
| P-1 | ~~Login com conta válida → Home com partidas reais~~ | ✅ Feito em 28/10 (ver ensaio acima) | — |
| P-2 | ~~Logout pelo menu~~ | ✅ Feito em 28/10 | — |
| P-3 | ~~Reabrir com sessão salva~~ | ✅ Feito em 28/10 | — |
| P-4 | Teste em aparelho físico | Nenhum aparelho conectado | `flutter run -d <id>` com depuração USB |
| P-5 | Build **release** do código atual | Não refeito; o último build release é de 19/10 (antes da KAN-27 e da KAN-32) | `flutter build apk --release`, só para uso local (ver aviso abaixo) |
| P-6 | Gravação do vídeo de contingência | Não gravado | `scrcpy --record demo.mp4` ou gravador do emulador |
| P-7 | Erro real de limite da API (HTTP 429) e abertura sem internet | Não provocados, para não consumir a cota | Opcional; coberto por testes automatizados |

## Aviso sobre builds

O APK contém hoje o token da football-data.org embutido no código. **Use os APKs apenas no emulador ou no aparelho da equipe. Não publique o APK no Classroom, no GitHub Releases nem em grupos.** A correção está nas tasks KAN-21 e KAN-102.
