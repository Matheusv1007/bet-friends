# Roteiro da demonstração (≈ 3 minutos dentro do Status Report)

> **Situação (01/11):** login, Home, Perfil, edição de nome, logout e os bloqueios de cadastro foram exercitados no app atual contra o Firebase real. O roteiro inteiro, em sequência, **ainda não foi reensaiado**, e o ensaio falado e cronometrado não foi feito. Os passos marcados "28/10" precisam ser conferidos no reensaio.

## Antes da apresentação

- [ ] Emulador aberto (`flutter emulators --launch Pixel_10_Pro`) ou aparelho espelhado (`scrcpy`).
- [ ] App instalado a partir da branch que será apresentada (`flutter run -d emulator-5554`). Os testes de integração removem o app do emulador.
- [ ] Conta de demonstração: **conta de teste A** (`qa_teste_a`). Não usar a conta B.
- [ ] Testar a senha antes. Durante a apresentação, digitar com a tela oculta, sem usar o ícone de olho e sem colar: a área de transferência do computador aparece no teclado do emulador.
- [ ] Internet funcionando; abrir a Home uma vez antes, para confirmar que a API responde.
- [ ] Sem outros dispositivos rodando o app ao mesmo tempo (limite de 10 chamadas por minuto da API, dividido com a `syncMatches`).
- [ ] Vídeo de contingência à mão.
- [ ] Sair da conta antes de começar, para mostrar o login do zero.

## Sequência

| # | Ação | O que falar | Verificado |
|---|---|---|---|
| 0 | Abrir o app | "O app verifica a sessão; sem login, vai para a tela de entrada." | ✅ 01/11 |
| 1 | Criar conta → preencher com o e-mail da conta A e senha nova → CADASTRAR | "O cadastro é real e recusa e-mail repetido, sem criar outra conta." | ✅ 01/11 |
| 2 | Voltar → digitar e-mail e senha → ENTRAR | "Autenticação real com Firebase Authentication." | ✅ 01/11 |
| 3 | Home: mostrar a saudação e rolar a lista de partidas | "O nome vem do perfil no Firestore, e as partidas reais, da API football-data.org. O saldo aparece como indisponível porque a carteira ainda não chegou a esta tela." | ✅ 01/11 |
| 4 | Aba Perfil | "O perfil está ligado ao UID e não expõe e-mail nem saldos." | ✅ 01/11 |
| 5 | Voltar → puxar para atualizar; "MAIS PARTIDAS" | "A lista também se atualiza sozinha a cada 30 segundos." | 🟡 28/10 |
| 6 | "Desafio Rápido" → Desafiar → escolher uma partida e um valor | "Só aparecem partidas elegíveis. Amigos e saldo desta tela ainda são demonstrativos." | 🟡 28/10 |
| 7 | ENVIAR DESAFIO | "O app avisa que é demonstrativo: criar desafios reais é o próximo passo." | 🟡 28/10 |
| 8 | Avatar → Sair da conta → confirmar | "Logout real, de volta ao Login." | ✅ 01/11 |

**Opcionais, se houver tempo:**

- Editar o nome na tela de Perfil: grava de verdade na conta A.
- Modo avião no Perfil: mostra o aviso e o bloqueio da edição. Desligar em seguida.

**Backend:** a carteira de 1.000 BetCoins e o lançamento inicial são reais, mas não aparecem no app. Se forem citados, mostrar como evidência de validação ([validacao-tecnica.md](validacao-tecnica.md)), sem abrir dados de contas no Console.

## Evitar durante a demo

- **Cadastro com username já usado:** cria a conta no Auth antes de recusar o username, deixando uma conta sem perfil.
- **Cadastro completo ao vivo:** cria dados permanentes no projeto real.
- Botões **"Detalhes do Desafio"** em "Desafios Ativos": sem ação.
- O card **"SALDO DISPONÍVEL — 1.500 fichas"** da Criar Desafio é fixo: não apresentá-lo como saldo da conta.

## Contingência

| Problema | Ação |
|---|---|
| API sem resposta ou "Limite de requisições atingido" | Mostrar o tratamento de erro (é uma funcionalidade) e passar para o vídeo de contingência |
| Login falha por rede | Conferir a internet e se o modo avião está desligado; se persistir, usar o vídeo |
| Emulador travado | Usar o vídeo; ter o aparelho físico como segunda opção |
