# BetFriends

Aplicativo Android, feito em Flutter, para desafios 1x1 entre amigos sobre partidas reais do Campeonato Brasileiro Série A. Os participantes escolhem uma partida, registram palpites diferentes e usam **BetCoins**, uma moeda fictícia que não pode ser comprada, vendida, sacada nem convertida em dinheiro. Ao fim da partida, o resultado oficial define o vencedor.

Projeto Final da disciplina de Desenvolvimento Mobile.

> **Estado atual (Segunda Entrega, 05/11/2026):** protótipo navegável com cadastro, login, perfil e carteira inicial **validados no Firebase real** em 01/11/2026, além de partidas reais. Security Rules e quatro Cloud Functions estão publicadas (plano Blaze). Saldo na interface, amizades e desafios reais ainda não chegaram ao app. Veja [O que está pronto](#o-que-está-pronto).

## Tecnologias

| Camada | Tecnologia |
|---|---|
| App | Flutter 3.47 / Dart 3.13, Android |
| Estado | Provider |
| Navegação | Navigator (com `AuthGate` baseado na sessão) |
| Autenticação | Firebase Authentication (e-mail e senha) |
| Banco de dados | Cloud Firestore (schema v2.0; Security Rules da KAN-22 publicadas em 29/10/2026) |
| Backend | Cloud Functions em TypeScript, Node 22 (quatro publicadas no projeto real; parte dos módulos ainda sem uso pelo app) |
| Dados de futebol | [football-data.org](https://www.football-data.org) API v4, competição BSA |
| HTTP | `package:http` |

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

As Cloud Functions `systemPing`, `createUserProfile`, `claimRecoveryBonus` e `syncMatches` estão publicadas no projeto real (plano Blaze, `southamerica-east1`). Não é preciso executar o backend localmente para rodar o app.

## Configuração do Firebase

O repositório já inclui a configuração **de cliente** do Firebase para Android (`android/app/google-services.json` e `lib/firebase_options.dart`). Esses arquivos identificam o projeto, mas não são credenciais administrativas. Não é preciso configurar nada para rodar o app.

- No projeto real, a tela de cadastro cria a conta no Auth e chama a `createUserProfile`, que cria perfil, username único e carteira. Os dados criados são permanentes: use e-mail fictício e combine com a equipe antes de criar contas de teste.
- As Security Rules por coleção (`firestore.rules`, KAN-22) foram **publicadas no projeto real em 29/10/2026**, idênticas às do repositório. Elas permitem ao usuário ler o próprio perfil e alterar só o nome de exibição; o resto continua negado ao app.
- Nunca versione credenciais administrativas, arquivos `.env`, `.secret.local` ou chaves de serviço.

> **Aviso de segurança conhecido:** hoje o token da football-data.org está no código do app. Isso contraria a arquitetura planejada, em que só o backend acessa o provedor. A função agendada `syncMatches` já roda no projeto real, com o token como segredo, e grava as partidas no Firestore (KAN-21, KAN-44 a KAN-50); o app lendo do Firestore (KAN-42) e a troca do token (KAN-102) estão pendentes. Até lá, **não distribua APKs** gerados a partir deste código e não reproduza o token em issues, prints ou documentos.

## Estrutura do projeto

```text
lib/
├── main.dart, app.dart          # inicialização do Firebase, providers e AuthGate
├── telas_autenticacao/          # AuthGate, Login, Cadastro
├── telas_principais/            # Home
├── tela_perfil/                 # Perfil e edição do nome de exibição
├── tela_criar_desafio/          # Criar Desafio
├── widgets_homePage/            # componentes da Home
├── provider/                    # AuthProvider, PartidasProvider
├── services/                    # Auth, API de partidas, Callable Functions, perfil
├── models/                      # PartidaModel, UserProfile, Carteira
└── data/firestore/              # coleções e repositório de perfil
functions/src/                   # Cloud Functions (TypeScript)
├── core/                        # autenticação, validação, Callable base, segredos
├── perfil/                      # createUserProfile e username único
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

### Validado no app com o Firebase real
- **Cadastro** (KAN-25, KAN-31, KAN-32, KAN-72): a tela cria a conta no Auth e chama a `createUserProfile`, que cria perfil, username único e carteira com 1.000 BetCoins em uma única transação. Dados inválidos e e-mail ou username repetidos são recusados. Sem rede, nada é gravado, e o cadastro pode ser concluído na mesma tela.
- **Login, logout e sessão:** com mensagens de erro em português. Depois de sair, o app volta ao Login.
- **Perfil** (`users/{uid}`, KAN-28, KAN-29, KAN-32): tela com nome e username, edição do nome com persistência depois de novo login, e leitura de terceiros e listagem negadas.
- **Comportamento sem conexão** (KAN-24): dados salvos com aviso; edição e cadastro bloqueados, sem falsa confirmação nem escrita pendente.
- **Carteira inicial:** um `INITIAL_BALANCE` +1000 por perfil. Chamadas simultâneas com a carteira já criada não duplicam nem alteram dados.
- **Partidas reais** do Brasileirão na Home e na tela Criar Desafio, com carregamento, erro, estado vazio, puxar para atualizar e atualização a cada 30 s. Hoje o app chama a API diretamente.
- **Home:** saudação com o nome do perfil e "Saldo indisponível" até a KAN-69. A barra inferior tem Home, Desafios e Perfil; o Ranking foi removido por ser pós-MVP.
- **Security Rules** por coleção (KAN-22), publicadas em 29/10/2026.

### Publicado, sem uso pelo app
- **Sincronização de partidas:** `syncMatches` (KAN-44 a KAN-50) grava em `matches` a cada 5 minutos por padrão, com consulta à temporada inteira a cada 6 horas (`docs/callable-functions.md` §10).
- **Liquidação automática** (KAN-82 a KAN-87): roda dentro da `syncMatches`, mas nunca liquidou em produção, porque não há desafios reais.
- **Recuperação de BetCoins** (`claimRecoveryBonus`, KAN-80): testada em emulador; sem tela (KAN-71) e sem execução em produção.

### Testado só em emulador
- **Negação de escrita pelo cliente** (saldo, `usernames` e lançamentos): com as mesmas regras publicadas. A execução em produção não foi autorizada, porque o banco não tem backup.
- **Disputa simultânea na primeira criação da carteira** e **retomada do cadastro pelo Perfil depois de reabrir o app**.
- **BetCoins no backend:** invariantes de saldo (KAN-73), registro auditável (KAN-79), reserva e liberação (KAN-74, KAN-75), premiação, perda e reembolso em empate (KAN-76 a KAN-78) e movimentações da liquidação, sem taxa (KAN-84). Fora a carteira inicial, nenhuma tela nem Callable as usa ainda.
- **Desafios no backend:** modelo `Challenge` com os oito estados oficiais e persistência (KAN-62), máquina de estados (KAN-63), `WAITING_RESULT` (KAN-67) e identificação, decisão e finalização da liquidação pelo resultado oficial (KAN-82, KAN-83, KAN-85, KAN-87). Ainda sem Callable de criação ou aceite.

### Apenas demonstrativo (interface sem funcionalidade real)
- **Desafios Ativos** na Home: exemplos fixos, com o selo "DEMONSTRATIVO".
- **Criar Desafio:** a escolha da partida usa dados reais, mas amigos ("DEMONSTRATIVO") e saldo ("1.500 fichas", valor fixo) não são reais, e o envio mostra "Modo demonstrativo: nenhum desafio foi salvo no banco."

### Pendente para o MVP
Amizades, criação e aceite de desafios pelo app, início de partida (KAN-66), saldo e extrato na interface, bônus de recuperação na interface, app lendo `matches` em vez da API, troca do token, histórico e tela de créditos ("Data provided by football-data.org").

### Limitações conhecidas
- O cadastro revela quando um e-mail já existe, e um username recusado deixa a conta no Auth sem perfil, a ser concluído depois.
- O Firestore do projeto está sem PITR, backups e proteção contra exclusão (01/11/2026).
- Os dados de teste `qa_*` permanecem no projeto real.

## Testes

Últimos resultados (01/11/2026, `805eea8`, Node 22.23.4, emuladores em `demo-betfriends`). Nenhum teste automatizado usa o Firebase de produção.

| Suíte | Resultado |
|---|---|
| `flutter test` | 176/176 |
| `flutter analyze` | 0 erros; 7 avisos já conhecidos (2 variáveis sem uso em teste e 5 nomes de arquivo) |
| Backend (`functions/`): `npm test`, testes puros | 118/118 |
| Backend + Security Rules no Firestore Emulator | 365/365 |
| `integration_test/` no Android contra os emuladores | 54/54 |

A validação controlada no Firebase real (01/11/2026) está em [`docs/entrega-2/validacao-tecnica.md`](docs/entrega-2/validacao-tecnica.md).

## Fonte dos dados

Dados de partidas fornecidos por football-data.org.

## Equipe

Pedro Simon · Guilherme Silva · Kauê Pimenta · Matheus Vasco
