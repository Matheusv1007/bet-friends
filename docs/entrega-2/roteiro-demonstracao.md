# Roteiro da demonstração (≈ 3 minutos dentro do Status Report)

> **Situação:** passos 0 a 9 executados no emulador em 28/10 (logins feitos manualmente pelo usuário; navegação por `adb`). Detalhes em [validacao-tecnica.md](validacao-tecnica.md). O ensaio **falado e cronometrado** ainda não foi feito.

## Antes da apresentação

- [ ] Emulador aberto (`flutter emulators --launch Pixel_10_Pro`) ou aparelho espelhado (`scrcpy`).
- [ ] App instalado a partir da branch que será apresentada (`flutter run -d emulator-5554`).
- [ ] Conta de demonstração válida e testada. Não mostre a senha na tela compartilhada.
- [ ] Internet funcionando; abrir a Home uma vez antes, para confirmar que a API responde.
- [ ] Sem outros dispositivos rodando o app ao mesmo tempo (limite de 10 chamadas por minuto da API).
- [ ] Vídeo de contingência à mão.
- [ ] Sair da conta antes de começar, para mostrar o login do zero.

## Sequência

| # | Ação | O que falar | Verificado em 28/10 |
|---|---|---|---|
| 0 | Abrir o app | "O app verifica a sessão; sem login, vai para a tela de entrada." | ✅ |
| 1 | Tocar em ENTRAR com os campos vazios | "Validação básica antes de chamar o Firebase." | ✅ |
| 2 | Digitar e-mail e senha da conta de demonstração → ENTRAR | "Autenticação real com Firebase Authentication." | ✅ |
| 3 | Home: rolar a lista de partidas | "Partidas reais do Brasileirão vindas da API football-data.org: ao vivo, próximas e finalizadas." | ✅ |
| 4 | Puxar para atualizar; tocar em "MAIS PARTIDAS" | "A lista também se atualiza sozinha a cada 30 segundos." | ✅ |
| 5 | Card "Desafio Rápido" → Desafiar | — | ✅ |
| 6 | Criar Desafio: escolher uma partida e um valor | "Só aparecem partidas elegíveis: finalizadas, canceladas e adiadas ficam de fora. Amigos e saldo ainda são demonstrativos." | ✅ |
| 7 | ENVIAR DESAFIO | "O app avisa que é demonstrativo: a gravação depende do backend, nosso próximo passo." | ✅ |
| 8 | Avatar → Sair da conta → confirmar | "Logout real; o botão Voltar não retorna à Home." | ✅ |
| 9 | (Opcional) Entrar de novo, fechar e reabrir o app | "A sessão é restaurada automaticamente." | ✅ |

## Evitar durante a demo

- Botão **CADASTRAR**: volta ao Login sem criar conta.
- Abas **Ranking** e **Perfil**: não abrem tela.
- Botões **"Detalhes do Desafio"** em "Desafios Ativos": sem ação.
- Não apresentar o nome e o saldo do cabeçalho como dados da conta, porque são fixos.
- Escudo da **Chapecoense** aparece como quadrado branco na Home (observado em 28/10); se o jogo estiver na lista, não chamar atenção para ele.

## Contingência

| Problema | Ação |
|---|---|
| API sem resposta ou "Limite de requisições atingido" | Mostrar o tratamento de erro (é uma funcionalidade) e passar para o vídeo de contingência |
| Login falha por rede | Conferir a internet do emulador; se persistir, usar o vídeo |
| Emulador travado | Usar o vídeo; ter o aparelho físico como segunda opção |
