# BetFriends

Aplicativo Android, feito em Flutter, para desafios 1x1 entre amigos sobre partidas reais do Campeonato Brasileiro Série A. Os participantes escolhem uma partida, registram palpites diferentes e usam **BetCoins**, uma moeda fictícia que não pode ser comprada, vendida, sacada nem convertida em dinheiro. Ao fim da partida, o resultado oficial define o vencedor.

Projeto Final da disciplina de Desenvolvimento Mobile.

> **Estado atual (Segunda Entrega, 05/11/2026):** protótipo navegável com autenticação real e listagem de partidas reais. A tela de Perfil e boa parte do backend (cadastro com username único, carteira e movimentações de BetCoins) estão implementadas e testadas **apenas nos emuladores do Firebase**. As Security Rules da KAN-22 foram **publicadas no projeto real em 29/10/2026**; as Cloud Functions ainda **não foram implantadas** (projeto no plano Spark). Amizades, desafios persistidos e liquidação ainda não foram iniciados. Veja [O que está pronto](#o-que-está-pronto).

## Tecnologias

| Camada | Tecnologia |
|---|---|
| App | Flutter 3.47 / Dart 3.13, Android |
| Estado | Provider |
| Navegação | Navigator (com `AuthGate` baseado na sessão) |
| Autenticação | Firebase Authentication (e-mail e senha) |
| Banco de dados | Cloud Firestore (schema v2.0; Security Rules da KAN-22 publicadas em 29/10/2026) |
| Backend | Cloud Functions em TypeScript, Node 22 (implementadas e testadas no emulador, sem deploy) |
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

As Cloud Functions **ainda não estão implantadas** no projeto Firebase: o projeto está no plano **Spark** e a Cloud Functions API não está ativa. O deploy depende do plano Blaze e de uma conta com permissão para liberar a invocação das Callables (ver [`docs/callable-functions.md`](docs/callable-functions.md) §7). Não é preciso executar o backend para rodar o app.

## Configuração do Firebase

O repositório já inclui a configuração **de cliente** do Firebase para Android (`android/app/google-services.json` e `lib/firebase_options.dart`). Esses arquivos identificam o projeto, mas não são credenciais administrativas. Não é preciso configurar nada para rodar o app.

- Para entrar no projeto real, use uma conta já cadastrada no Firebase Authentication (peça uma conta de teste à equipe). A tela de cadastro cria a conta no Auth, mas o perfil depende da `createUserProfile`, que ainda não foi implantada: no projeto real, a conta fica criada sem perfil.
- As Security Rules por coleção (`firestore.rules`, KAN-22) foram **publicadas no projeto real em 29/10/2026**, idênticas às do repositório. Elas permitem ao usuário ler o próprio perfil e alterar só o nome de exibição; o resto continua negado ao app. Como ainda não há perfis no projeto real (a criação depende da `createUserProfile`), a tela de Perfil só foi validada nos emuladores.
- Nunca versione credenciais administrativas, arquivos `.env`, `.secret.local` ou chaves de serviço.

> **Aviso de segurança conhecido:** hoje o token da football-data.org está no código do app. Isso contraria a arquitetura planejada, em que só o backend acessa o provedor. O backend já guarda o token como segredo (KAN-21) e tem a função agendada `syncMatches`, que busca as partidas e as grava no Firestore (KAN-44 a KAN-50), mas ela ainda não foi implantada; o app lendo do Firestore e a troca do token (KAN-102) estão pendentes. Até lá, **não distribua APKs** gerados a partir deste código e não reproduza o token em issues, prints ou documentos.

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

### Funciona no app com o Firebase real
- **Login** com e-mail e senha (Firebase Authentication), com mensagens de erro em português.
- **Sessão:** ao abrir, o app restaura a sessão e vai direto para a Home.
- **Logout** pelo menu do avatar, com confirmação. Depois de sair, o botão Voltar não retorna às telas protegidas.
- **Partidas reais** do Brasileirão (ao vivo, próximas e finalizadas recentes) na Home e na tela Criar Desafio, com carregamento, mensagem de erro, estado vazio, "Tentar novamente", puxar para atualizar e atualização automática a cada 30 s. Hoje o app chama a API diretamente.
- **Security Rules** por coleção (KAN-22): testadas no emulador e publicadas no projeto real em 29/10/2026.
- **Falha de atualização:** se a API falhar depois de já ter carregado, os dados anteriores continuam na tela com um aviso.
- **Home sem dados fictícios no cabeçalho:** saudação "Olá!" (ou "Olá, {nome}" quando há perfil) e "Saldo indisponível". A barra inferior tem Home, Desafios e Perfil; o Ranking foi removido por ser pós-MVP.

### Implementado e testado só nos emuladores do Firebase
- **Perfil** (`users/{uid}`, vinculado ao UID): tela de Perfil, edição do nome de exibição e comportamento seguro sem conexão (KAN-24, KAN-28, KAN-29, KAN-32). No projeto real, as Security Rules já estão publicadas, mas ainda não há perfis: a criação depende da `createUserProfile`, sem deploy.
- **Cadastro** (KAN-25, KAN-31, KAN-32 e KAN-72): a tela cria a conta no Firebase Auth e chama a `createUserProfile`, que cria perfil, username único e carteira com 1.000 BetCoins em uma única transação. Se o perfil falhar, a sessão é mantida e o cadastro pode ser concluído na mesma tela ou depois, pela aba Perfil.
- **BetCoins no backend:** invariantes de saldo (KAN-73), registro auditável de transações (KAN-79), reserva e liberação (KAN-74, KAN-75), premiação, perda e reembolso em empate (KAN-76 a KAN-78) e as movimentações da liquidação de um desafio numa única transação, sem taxa (KAN-84). São funções internas: nenhuma tela nem Callable as usa ainda.
- **Partidas no backend:** modelo `Match`, mapeamento de status e de resultado (KAN-46 a KAN-48), Adapter da Football-Data (KAN-44), FootballService (KAN-45), sincronização com `matches` (KAN-49) e a função agendada `syncMatches`, a cada 5 minutos por padrão (KAN-50; configuração em `docs/callable-functions.md` §10). Sem deploy, o app continua chamando a API diretamente.
- **Desafios no backend:** modelo `Challenge` com os oito estados oficiais e persistência em `challenges` (KAN-62), máquina de estados com as transições do Plano §7, sem edição de participantes, partida, valor ou palpites (KAN-63), passagem para `WAITING_RESULT` quando a partida termina, é suspensa ou vai para revisão (KAN-67), identificação dos desafios aptos para liquidação: só com partida finalizada e resultado oficial; suspensa e em revisão ficam aguardando, sem mover BetCoins, e aparecem no log (KAN-82, KAN-87), decisão de vencedor ou empate estrutural pelo resultado oficial (KAN-83) e finalização do desafio junto com a liquidação, uma única vez (KAN-85). Ainda sem Callable de criação ou aceite, e sem job que chame essas rotinas (KAN-86).

### Apenas demonstrativo (interface sem funcionalidade real)
- **Desafios Ativos** na Home: exemplos fixos, com o selo "DEMONSTRATIVO".
- **Criar Desafio:** a escolha da partida usa dados reais, mas amigos ("DEMONSTRATIVO") e saldo ("1.500 fichas", valor fixo) não são reais, e o envio mostra "Modo demonstrativo: nenhum desafio foi salvo no banco."

### Pendente para o MVP
Deploy das Functions (as regras já foram publicadas), amizades, desafios persistidos com palpites e estados, saldo e extrato na interface, bônus de recuperação, sincronização das partidas pelo backend, liquidação automática, histórico e tela de créditos ("Data provided by football-data.org").

## Testes

Últimos resultados registrados (29/10/2026, `qas` em `5ed4796`):

| Suíte | Resultado |
|---|---|
| `flutter test` | 128/128 |
| `flutter analyze` | 0 erros; 7 avisos já conhecidos (2 warnings em teste e 5 de nome de arquivo) |
| Backend (`functions/`): testes puros + Firestore Emulator | 131/131 (58 puros + 73 no emulador) |
| Security Rules no Firestore Emulator | 77/77 |
| `integration_test/` no Android contra os emuladores | 33/33 na última execução, em 28/10/2026; não reexecutados depois (o app só ganhou uma constante desde então) |

Validação antes da publicação das Security Rules (29/10/2026, `qas` em `74a9bcf`, Node 22.23.4, projeto `demo-betfriends`):

| Suíte | Resultado |
|---|---|
| Backend (`functions/`): `npm test`, testes puros | 67/67 |
| Backend + Security Rules no Firestore Emulator | 226/226 (149 do backend + 77 das rules) |

Nenhum teste usa o Firebase de produção.

## Fonte dos dados

Dados de partidas fornecidos por football-data.org.

## Equipe

Pedro Simon · Guilherme Silva · Kauê Pimenta · Matheus Vasco
