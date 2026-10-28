# BetFriends

Aplicativo Android, feito em Flutter, para desafios 1x1 entre amigos sobre partidas reais do Campeonato Brasileiro Série A. Os participantes escolhem uma partida, registram palpites diferentes e usam **BetCoins**, uma moeda fictícia que não pode ser comprada, vendida, sacada nem convertida em dinheiro. Ao fim da partida, o resultado oficial define o vencedor.

Projeto Final da disciplina de Desenvolvimento Mobile.

> **Estado atual (Segunda Entrega, novembro de 2026):** protótipo navegável, com autenticação real e listagem de partidas reais. O núcleo do produto (perfil, BetCoins, amizades, desafios persistidos e liquidação) ainda está em desenvolvimento. Veja [O que está pronto](#o-que-está-pronto).

## Tecnologias

| Camada | Tecnologia |
|---|---|
| App | Flutter 3.47 / Dart 3.13, Android |
| Estado | Provider |
| Navegação | Navigator (com `AuthGate` baseado na sessão) |
| Autenticação | Firebase Authentication (e-mail e senha) |
| Banco de dados | Cloud Firestore (estrutura preparada) |
| Backend | Cloud Functions em TypeScript, Node 22 (estrutura preparada) |
| Dados de futebol | [football-data.org](https://www.football-data.org) API v4, competição BSA |
| HTTP | `package:http` |

## Requisitos do ambiente

- Flutter **3.47** (canal stable) com Dart **3.13.3 ou superior**.
- Android SDK com build-tools e um emulador (AVD) ou aparelho com depuração USB.
- JDK 17 ou superior (o JDK embutido no Android Studio serve).
- Git.
- Opcional, só para o backend: Node.js 22 e Firebase CLI.

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

```bash
cd functions
npm ci
npm test                        # testes das Callable Functions
```

As Cloud Functions **ainda não estão implantadas** no projeto Firebase. Não é preciso executar o backend para rodar o app.

## Configuração do Firebase

O repositório já inclui a configuração **de cliente** do Firebase para Android (`android/app/google-services.json` e `lib/firebase_options.dart`). Esses arquivos identificam o projeto, mas não são credenciais administrativas. Não é preciso configurar nada para rodar o app.

- Para entrar, é necessária uma conta já cadastrada no Firebase Authentication do projeto, já que o cadastro pelo app ainda não está ativo. Peça uma conta de teste à equipe.
- As regras do Firestore (`firestore.rules`) bloqueiam todo acesso direto até que as regras definitivas sejam publicadas.
- Nunca versione credenciais administrativas, arquivos `.env` ou chaves de serviço.

> **Aviso de segurança conhecido:** hoje o token da football-data.org está no código do app. Isso contraria a arquitetura planejada, em que só o backend acessa o provedor. A correção está planejada nas tasks KAN-21 e KAN-102. Até lá, **não distribua APKs** gerados a partir deste código e não reproduza o token em issues, prints ou documentos.

## Estrutura do projeto

```text
lib/
├── main.dart, app.dart          # inicialização do Firebase, providers e AuthGate
├── telas_autenticacao/          # AuthGate, Login, Cadastro
├── telas_principais/            # Home
├── tela_criar_desafio/          # Criar Desafio
├── widgets_homePage/            # componentes da Home
├── provider/                    # AuthProvider, PartidasProvider
├── services/                    # Auth, API de partidas, Callable Functions, perfil
├── models/                      # PartidaModel, UserProfile
└── data/firestore/              # coleções e repositório de perfil
functions/                       # Cloud Functions (TypeScript)
test/                            # testes Flutter
docs/                            # schema do Firestore, guia de Functions e material da Entrega 2
android/                         # projeto Android
```

## O que está pronto

### Implementado e testado
- **Login** com e-mail e senha (Firebase Authentication), com mensagens de erro em português.
- **Sessão:** ao abrir, o app restaura a sessão e vai direto para a Home.
- **Logout** pelo menu do avatar, com confirmação. Depois de sair, o botão Voltar não retorna às telas protegidas.
- **Partidas reais** do Brasileirão (ao vivo, próximas e finalizadas recentes) na Home e na tela Criar Desafio, com carregamento, mensagem de erro, estado vazio, "Tentar novamente", puxar para atualizar e atualização automática a cada 30 s.
- **Falha de atualização:** se a API falhar depois de já ter carregado, os dados anteriores continuam na tela com um aviso.
- **Perfil (camada de dados):** modelo e repositório de `users/{uid}` com o UID do Firebase como identidade. Ainda não está ligado à interface e não grava dados enquanto as regras do Firestore não forem definidas.

### Apenas demonstrativo (interface sem funcionalidade real)
- **Cadastro:** o formulário existe, mas o botão "CADASTRAR" não cria conta e apenas volta ao Login.
- **Cabeçalho da Home:** nome ("Olá, Pedro") e saldo ("1.500 fichas") fixos para qualquer usuário.
- **Desafios Ativos** na Home: exemplos fixos.
- **Criar Desafio:** a escolha da partida usa dados reais, mas amigos e saldo são fixos, e o envio mostra "Modo demonstrativo: nenhum desafio foi salvo no banco."
- **Abas Ranking e Perfil:** ainda não abrem nenhuma tela.

### Pendente para o MVP
Cadastro real, perfil visível, amizades, BetCoins (saldo inicial de 1.000, reserva, premiação, extrato e recuperação), desafios persistidos com palpites e estados, sincronização das partidas pelo backend, liquidação automática, histórico e tela de créditos ("Data provided by football-data.org").

## Testes

- `flutter test`: 65 testes (AuthGate, login, logout, partidas, perfil).
- `npm test` em `functions/`: 7 testes da estrutura de Callable Functions.

## Fonte dos dados

Dados de partidas fornecidos por football-data.org.

## Equipe

Pedro Simon · Guilherme Silva · Kauê Pimenta · Matheus Vasco
