# Rodando o app em 2 terminais ao mesmo tempo (demonstração com duas contas)

Para demonstrar as funcionalidades sociais (amizade, desafio enviado, desafio recebido e aceito) é preciso **dois usuários ao mesmo tempo**. A solução é rodar o app em **dois dispositivos**, cada um no seu terminal:

| Terminal | Dispositivo | Conta |
|---|---|---|
| **1** | Emulador `Pixel_10_Pro` (normalmente `emulator-5554`) | Conta A |
| **2** | Emulador `Pixel_10_Pro_B` (normalmente `emulator-5556`) | Conta B |

Os dois AVDs já existem nesta máquina (`flutter emulators`). Em outra máquina, crie o segundo pelo Device Manager do Android Studio ou use um aparelho físico no lugar dele.

> **O app usa o Firebase real da equipe** (Auth, Firestore e Functions publicadas). Não precisa subir emuladores de backend e não há nada a configurar além do `flutter run`. Por isso, tudo que as contas fizerem é gravado de verdade: use contas de teste, nunca dados pessoais.

## 0. Antes de começar

Execute `flutter pub get` e `flutter run` na pasta **`bet-friends`**, onde está o `pubspec.yaml`. Se o terminal estiver em `Projeto-Final`, entre com `cd bet-friends`. Abrir o emulador não muda a pasta do terminal. A ausência do Chrome no `flutter doctor` não impede executar no Android.

```bash
flutter pub get
flutter doctor        # Flutter e Android toolchain sem problemas
```

Tenha **duas contas de teste que sejam amigas** ou que possam virar amigas durante a demonstração (e-mails fictícios; combine com a equipe antes de criar contas novas). Sem amizade aceita, o desafio não pode ser enviado.

### 0.1 Erro de recurso Android após atualizar o app

Se o build falhar com `resource drawable/launch_background not found` após a mudança do splash, mesmo com `android/app/src/main/res/drawable/launch_background.xml` presente, o cache incremental pode ainda apontar para a antiga variante `drawable-v21`.

Encerre os `flutter run` dos dois terminais antes de limpar a pasta de build compartilhada. Na raiz do projeto, execute **uma vez**:

```bash
flutter clean
flutter pub get
flutter run -d emulator-5554
```

Espere a primeira instância abrir antes de iniciar a segunda. A limpeza remove artefatos gerados, não contas, dados do Firebase ou emuladores. Não é necessário trocar o Java/Kotlin por causa desse erro de recurso.

## 1. Abrir os dois emuladores

Em qualquer terminal (cada comando devolve o prompt e deixa o emulador rodando em segundo plano):

```bash
flutter emulators --launch Pixel_10_Pro
flutter emulators --launch Pixel_10_Pro_B
```

Espere os dois terminarem de iniciar (home do Android visível) e confira os IDs:

```bash
flutter devices
# ou
adb devices
```

Devem aparecer dois itens `emulator-XXXX`. **Use os IDs que aparecerem**; abaixo, `emulator-5554` e `emulator-5556`.

## 2. Terminal 1: conta A

Na **raiz** do repositório:

```bash
flutter run -d emulator-5554
```

Espere o app abrir no emulador A (`Syncing files to device...` e a tela de login).

## 3. Terminal 2: conta B

Abra **outro terminal**, na raiz do repositório, e só **depois** do app do terminal 1 ter aberto:

```bash
flutter run -d emulator-5556
```

> Suba um de cada vez. Dois `flutter run` iniciando juntos disputam o lock do Flutter e a pasta `build/`/Gradle (aparece `Waiting for another flutter command to release the startup lock`). Depois que os dois estão rodando, eles são independentes.

Em cada terminal: `r` hot reload, `R` hot restart, `q` encerra só aquela instância.

> Dica: a janela de cada emulador mostra o app; o terminal só mostra logs. Para saber de qual emulador é cada janela, o título dela traz o nome do AVD (`Pixel_10_Pro` ou `Pixel_10_Pro_B`).

## 4. Roteiro da demonstração com as duas contas

Faça login na **conta A** no emulador 1 e na **conta B** no emulador 2. A barra inferior tem **Home / Desafiar / Perfil**.

| # | Onde | Ação | O que mostrar |
|---|---|---|---|
| 1 | A e B | Home | Saudação com o nome do perfil, partidas do Brasileirão e a carteira |
| 2 | A | Perfil → **BUSCAR AMIGOS** → buscar por nome ou `@username` da B → enviar solicitação | Pedido de amizade criado |
| 3 | B | Perfil → **SOLICITAÇÕES DE AMIZADE** → **Aceitar** | Aparece "Agora você e {nome} são amigos!" |
| 4 | A e B | Perfil → **MEUS AMIGOS** | Cada um vê o outro na lista |
| 5 | A | **Novo desafio** na Home, aba **Desafiar**, ou **Desafiar nesta partida** nos detalhes: escolher amigo (B), partida, palpite e valor → **Enviar desafio** | Desafio enviado; aparece como pendente enviado na Home da A |
| 6 | B | Home → recebidos → **Responder** → **Confirmar e aceitar** (ou **Recusar**, com confirmação, na lista) | O desafio passa a ativo para os dois; o saldo reflete a reserva |
| 7 | A e B | Home → desafios ativos → detalhes do desafio | Os dois lados veem o mesmo desafio |

> Os nomes dos botões vêm do código em `lib/` (`tela_amigos/`, `tela_criar_desafio/`, `widgets_home_page/`), mas **este roteiro não foi ensaiado ponta a ponta**. Faça um ensaio antes de apresentar e ajuste a tabela ao que a tela realmente mostra. O estado real de cada funcionalidade está em [`entrega-2/funcionalidades.md`](entrega-2/funcionalidades.md), com data de 01/11, anterior ao código atual da `qas`.

Cuidados na apresentação:

- Antes de rodar, abra a Home uma vez em cada emulador para garantir que as partidas carregam.
- Digite as senhas com a tela oculta e sem colar (a área de transferência do computador aparece no teclado do emulador).
- Cadastro com username já usado deixa uma conta sem perfil; evite criar contas ao vivo.
- Dois emuladores consomem bastante memória e CPU. Feche outros programas pesados antes.

## 5. Encerrando os processos

### 5.1 Jeito normal

1. Em cada terminal, tecle `q` (ou `Ctrl+C`). Isso encerra o `flutter run` e fecha o app daquele emulador.
2. Feche os emuladores:

```bash
adb -s emulator-5554 emu kill
adb -s emulator-5556 emu kill
```

Ou feche a janela de cada um.

### 5.2 Quando algo ficou preso

Sintomas: `flutter run` travado, `Waiting for another flutter command to release the startup lock`, emulador sem resposta, dispositivo que não aparece.

```bash
# Ver o que está rodando
pgrep -af 'flutter_tools|qemu-system|emulator'
adb devices
```

```bash
# Encerrar só os flutter run (um terminal por vez, ou todos de uma vez)
pkill -f flutter_tools

# Fechar o app em um dispositivo específico (applicationId: com.unirv.betfriends)
adb -s emulator-5554 shell am force-stop com.unirv.betfriends
adb -s emulator-5556 shell am force-stop com.unirv.betfriends

# Desligar emuladores que não respondem
adb -s emulator-5554 emu kill
adb -s emulator-5556 emu kill
pkill -f qemu-system          # último recurso: mata TODOS os emuladores Android

# Gradle e ADB
(cd android && ./gradlew --stop)   # daemons do Gradle
adb kill-server                    # reinicia o ADB; depois: adb start-server
```

Se a lock do Flutter continuar presa depois de matar os processos, confira se não sobrou outro `flutter`/`dart` (`pgrep -af 'flutter|dart'`) e repita o `pkill`.

Conferir que tudo parou:

```bash
pgrep -af 'flutter_tools|qemu-system' || echo "nada rodando"
adb devices      # lista vazia
```

### 5.3 Cuidados

- `pkill -f` casa com a linha de comando inteira: veja antes com `pgrep -af <nome>` para não matar processos de outro projeto.
- `pkill -f qemu-system` encerra **todos** os emuladores, inclusive de outros projetos.
- Encerrar o app ou o emulador não apaga nada no Firebase: contas, amizades e desafios criados na demonstração permanecem.

## 6. Apêndice: backend local (só para desenvolver as Functions)

Para alterar as Cloud Functions, existe a opção de rodar os emuladores do Firebase em um terminal e o app com `--dart-define=USE_FUNCTIONS_EMULATOR=true` em outro. O app só redireciona as **Callable Functions**; Auth e Firestore continuam reais. Passo a passo, portas e como matar os emuladores em [`callable-functions.md`](callable-functions.md) §6 e §9. Não é necessário para a demonstração.
