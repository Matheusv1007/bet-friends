# BetFriends

Aplicativo Android, feito em Flutter, para desafios 1x1 entre amigos sobre partidas reais do Campeonato Brasileiro Série A. Os participantes escolhem uma partida, registram palpites diferentes e usam **BetCoins**, uma moeda fictícia que não pode ser comprada, vendida, sacada nem convertida em dinheiro. Ao fim da partida, o resultado oficial define o vencedor.

Projeto Final da disciplina de Desenvolvimento Mobile.

> **Estado atual (19/11/2026, `qas`):** app com cadastro, login, perfil, carteira, amizades e desafios reais. Há **14 Cloud Functions publicadas**. As partidas são lidas do Firestore; só o backend acessa a API de futebol.

## Tecnologias

| Camada | Tecnologia |
|---|---|
| App | Flutter 3.47 / Dart 3.13, Android |
| Estado | Provider |
| Navegação | Navigator (com `AuthGate` baseado na sessão) |
| Autenticação | Firebase Authentication (e-mail e senha) |
| Banco de dados | Cloud Firestore (schema v2.0; Security Rules da KAN-22 publicadas em 29/10/2026) |
| Backend | Cloud Functions em TypeScript, Node 22 (14 publicadas no projeto real, plano Blaze) |
| Dados de futebol | [football-data.org](https://www.football-data.org) API v4, competição BSA; sincronizados pelo backend e lidos pelo app via Firestore |

## Requisitos do ambiente

- Flutter **3.47** (canal stable) com Dart **3.13.3 ou superior**.
- Android SDK com build-tools e um emulador (AVD) ou aparelho com depuração USB.
- JDK 17 ou superior para o build Android (o JDK embutido no Android Studio serve). Os emuladores do Firebase exigem **JDK 21**.
- Git.
- Opcional, só para o backend e os testes com emuladores: Node.js 22 e Firebase CLI.

## Instalação no Arch Linux

```bash
# 1. Ferramentas básicas
sudo pacman -S --needed git unzip base-devel

# 2. Flutter (repositório oficial, canal stable)
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc   # ou ~/.bashrc
source ~/.zshrc

# 3. Android Studio (AUR), que instala SDK, emulador e JDK
yay -S android-studio            # ou outro helper do AUR (paru etc.)
# Abra o Android Studio uma vez, conclua o assistente do SDK e crie um AVD
# em Device Manager.

# 4. Aceleração do emulador (KVM)
sudo usermod -aG kvm "$USER"   # depois, encerre a sessão e entre de novo

# 5. Licenças do Android e diagnóstico
flutter doctor --android-licenses
flutter doctor
```

O `flutter doctor` deve mostrar **Flutter** e **Android toolchain** marcados. A falta do Chrome não afeta o build Android.

## Executando o projeto

```bash
git clone https://github.com/Matheusv1007/bet-friends.git
cd bet-friends
git switch qas          # branch de integração com o código atual do app
flutter pub get
```

> A branch padrão `main` ainda contém o template inicial do Flutter. O código atual está em `qas`; a promoção `qas → main` depende de decisão da equipe.

### No emulador

```bash
flutter emulators                         # lista os AVDs disponíveis
flutter emulators --launch <id_do_avd>    # ex.: Pixel_10_Pro
flutter devices                           # aguarde aparecer emulator-5554
flutter run -d emulator-5554
```

Com o app aberto, `r` faz hot reload, `R` faz hot restart e `q` encerra.

### Outros comandos

```bash
flutter analyze                 # análise estática
flutter test                    # testes de unidade e de widget
flutter build apk --debug       # gera build/app/outputs/flutter-apk/app-debug.apk
```

### Build de release (Android)

O release é assinado com o keystore descrito em `android/key.properties`, que **não vai para o git** (já ignorado, assim como `*.jks` e `*.keystore`). Para gerar o keystore uma única vez (guarde o arquivo e as senhas fora do repositório):

```bash
keytool -genkeypair -v -keystore ~/betfriends-release.jks -alias betfriends \
  -keyalg RSA -keysize 2048 -validity 10000
```

Crie `android/key.properties`:

```properties
storeFile=/caminho/absoluto/betfriends-release.jks
storePassword=<senha do keystore>
keyAlias=betfriends
keyPassword=<senha da chave>
```

Depois, `flutter build apk --release` ou `flutter build appbundle --release`. Sem `android/key.properties`, o Gradle avisa e assina com a chave de debug (útil só para `flutter run --release`; o artefato não é publicável). Se mudar de keystore, registre o novo SHA-1 no Firebase e na restrição da chave de API (ver "Configuração do Firebase").

### Backend (opcional)

Com o Node 22 no PATH, sem trocar o Node do sistema (ver [`docs/callable-functions.md`](docs/callable-functions.md) §9):

```bash
cd functions
npm ci
npm test                        # compila e roda os testes puros (os de emulador são pulados)
```

Os testes que usam o Firestore Emulator (backend e Security Rules) rodam na raiz do repositório, sempre com um projeto `demo-*`:

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk PATH="$JAVA_HOME/bin:$PATH" \
  firebase emulators:exec --only firestore --project demo-betfriends \
  "$(command -v node) --test --test-concurrency=1 'functions/lib/test/**/*.test.js'"   # backend (após npm test)

JAVA_HOME=/usr/lib/jvm/java-21-openjdk PATH="$JAVA_HOME/bin:$PATH" \
  firebase emulators:exec --only firestore --project demo-betfriends \
  "$(command -v node) --test --test-concurrency=1 'tests/firestore-rules/*.test.mjs'"  # Security Rules
```

Os padrões de arquivos ficam entre aspas simples: o `node --test` do Node 22 não aceita pasta como argumento.

Os testes de integração do app no Android contra os emuladores estão descritos em [`integration_test/README.md`](integration_test/README.md).

As 14 Cloud Functions exportadas em `functions/src/index.ts` estão publicadas no projeto real (`southamerica-east1`), conforme o registro de deploy de 19/11 em `docs/callable-functions.md` §7. Não é preciso executar o backend localmente para rodar o app.

## Configuração do Firebase

O repositório já inclui a configuração **de cliente** do Firebase para Android (`android/app/google-services.json` e `lib/firebase_options.dart`). Esses arquivos identificam o projeto, mas não são credenciais administrativas. Não é preciso configurar nada para rodar o app.

- No projeto real, a tela de cadastro cria a conta no Auth e chama a `createUserProfile`, que cria perfil, username único e carteira. Os dados criados são permanentes: use e-mail fictício e combine com a equipe antes de criar contas de teste.
- As Security Rules permitem ler o próprio perfil/carteira, amizades e desafios dos quais se participa, partidas para usuários autenticados e transações do próprio usuário. O cliente só altera o próprio nome e `updatedAt`; as demais escritas são exclusivas do backend. `usernames` e caminhos não declarados permanecem bloqueados.
- Nunca versione credenciais administrativas, `.secret.local` ou chaves de serviço. A exceção pública `functions/.env.betfriends-unirv-2026` contém só App Check e agenda, sem segredos.
- A chave `AIza…` de `google-services.json` e `firebase_options.dart` é de cliente, mas deve estar restrita no Google Cloud Console (APIs e serviços → Credenciais): restrição de aplicativo Android com o pacote `com.unirv.betfriends` e o SHA-1 do keystore, e restrição de API só às APIs do Firebase usadas. Sem isso, qualquer pessoa que leia o repositório pode usar a chave por fora do app.

> **Nota de segurança:** o token da football-data.org fica no Secret Manager (`FOOTBALL_DATA_TOKEN`), nunca no app. A credencial antiga aparece no histórico (`8462ffe`, `8f685f7`, removida em `34fd242`); a confirmação manual da revogação está descrita em `docs/callable-functions.md` §8.3. Não reproduza tokens.

## Estrutura do projeto

```text
lib/
├── main.dart, app.dart          # inicialização do Firebase, providers e AuthGate
├── telas_autenticacao/          # AuthGate, Login, Cadastro
├── telas_principais/            # Home
├── tela_perfil/                 # Perfil e edição do nome de exibição
├── tela_criar_desafio/          # Criar Desafio
├── tela_amigos/                 # busca, solicitações e lista de amigos
├── tela_sobre/                  # informações e créditos
├── widgets_home_page/           # componentes da Home
├── provider/                    # AuthProvider, PartidasProvider
├── services/                    # Auth, partidas via Firestore, Callables, perfil
├── models/                      # PartidaModel, UserProfile, Carteira
└── data/firestore/              # coleções e repositório de perfil
functions/src/                   # Cloud Functions (TypeScript)
├── core/                        # autenticação, validação, Callable base, segredos
├── perfil/                      # createUserProfile e username único
├── amigos/                      # solicitações e listagem de amizades
├── betcoins/                    # saldos, carteira inicial, ledger, reserva, desfecho
├── partidas/                    # modelo Match, Adapter da Football-Data (status e resultado) e FootballService
└── desafios/                    # modelo Challenge, persistência e máquina de estados
test/                            # testes Flutter (unidade e widget)
integration_test/                # testes no Android contra os emuladores do Firebase
tests/firestore-rules/           # testes das Security Rules
docs/                            # schema do Firestore, guia de Functions e material da Entrega 2
android/                         # projeto Android
```

## O que está pronto

### Implementado no app e backend
- **Cadastro, login e perfil:** Auth, criação atômica de perfil/username/carteira, sessão e edição do nome. A validação inicial no Firebase real ocorreu em 01/11; sem rede, operações sensíveis não mostram confirmação falsa.
- **Carteira:** saldo total, reservado e disponível reais; 1.000 BetCoins iniciais por perfil, com registro auditável no backend.
- **Partidas:** Home e Criar Desafio leem `matches` pelo Firestore, com carregamento, erro e cache. Não há chamada do app à Football-Data.org.
- **Amizades:** busca por username, envio, aceite e recusa de solicitações e lista de amigos via Callables.
- **Desafios:** criação com amigo e partida reais, aceite com palpite diferente, recusa e cancelamento pendente; a Home observa os desafios do usuário.
- **Informações e créditos:** tela em `tela_sobre/`, com atribuição à football-data.org.
- **Sincronização e liquidação:** `syncMatches` consulta o provedor a cada 5 minutos e a temporada inteira a cada 6 horas por padrão; inicia, acompanha e liquida desafios automaticamente. As Callables de desafio já estão publicadas, portanto a liquidação pode alcançar desafios reais. Não se afirma aqui que uma liquidação específica foi observada em produção.
- **Security Rules e transações:** escritas financeiras exclusivas do backend; invariantes, concorrência, reservas, liberação e liquidação têm testes unitários e de emulador.

### Pendente para o MVP
Extrato e bônus de recuperação na interface; concluir a interface de histórico (já há serviço/repositório). A Callable `claimRecoveryBonus` já está publicada. A troca de token não é migração pendente do app: o provedor já é exclusivo do backend; resta a confirmação operacional da revogação antiga (§8.3 do guia de Functions).

### Limitações conhecidas
- O cadastro revela quando um e-mail já existe, e um username recusado deixa a conta no Auth sem perfil, a ser concluído depois.
- O Firestore do projeto está sem PITR, backups e proteção contra exclusão (01/11/2026).
- Os dados de teste `qa_*` permanecem no projeto real.

## Testes

Nenhum teste automatizado usa o Firebase de produção: o backend roda no Firestore Emulator, com o projeto `demo-betfriends`.

### Integração contínua

O workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda a cada pull request e a cada push para `qas` e `main`, em quatro jobs independentes:

| Job | O que roda |
|---|---|
| **App Flutter (analyze e test)** | `flutter analyze` sem avisos e `flutter test` |
| **Android (APK debug)** | `flutter build apk --debug`, JDK 21, caches de Flutter e Gradle |
| **Functions (build e testes unitários)** | `npm ci`, `npm test` e `node --test tool/kan53/medicao.test.mjs` |
| **Backend e Security Rules (Firestore Emulator)** | testes de backend e rules no emulador, Node 22, JDK 21 e Firebase CLI 15.32.1 fixado no lockfile |

Para proteção da `qas`, marque os quatro nomes exatos acima como obrigatórios em *Settings → Branches → Branch protection rules → Require status checks to pass*. O `integration_test/` não roda no CI, pois precisa de dispositivo/emulador Android; veja [`integration_test/README.md`](integration_test/README.md).

Os mesmos comandos rodam localmente (seções acima e `docs/callable-functions.md` §9.3).

A validação controlada no Firebase real (01/11/2026) está em [`docs/entrega-2/validacao-tecnica.md`](docs/entrega-2/validacao-tecnica.md).

## Fonte dos dados

Dados de partidas fornecidos por football-data.org.

## Equipe

Pedro Simon · Guilherme Silva · Kauê Pimenta · Matheus Vasco
