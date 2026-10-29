# Roteiro da demonstração (≈ 3 minutos dentro do Status Report)

> **Situação (29/10):** os passos 0 a 9 foram executados no emulador em 28/10 com o código do PR #14 (logins feitos manualmente pelo usuário; navegação por `adb`). Desde então a Home mudou (Ranking removido, cabeçalho neutro) e a aba Perfil passou a abrir uma tela. **O roteiro precisa ser refeito no app atual**, e o ensaio falado e cronometrado ainda não foi feito. Detalhes em [validacao-tecnica.md](validacao-tecnica.md).

## Antes da apresentação

- [ ] Emulador aberto (`flutter emulators --launch Pixel_10_Pro`) ou aparelho espelhado (`scrcpy`).
- [ ] App instalado a partir da branch que será apresentada (`flutter run -d emulator-5554`).
- [ ] Conta de demonstração válida e testada. Não mostre a senha na tela compartilhada.
- [ ] Internet funcionando; abrir a Home uma vez antes, para confirmar que a API responde.
- [ ] Sem outros dispositivos rodando o app ao mesmo tempo (limite de 10 chamadas por minuto da API).
- [ ] Abrir a aba **Perfil** com a conta de demonstração e decidir se ela entra na demo (ver "Evitar durante a demo").
- [ ] Vídeo de contingência à mão.
- [ ] Sair da conta antes de começar, para mostrar o login do zero.

## Sequência

| # | Ação | O que falar | Verificado |
|---|---|---|---|
| 0 | Abrir o app | "O app verifica a sessão; sem login, vai para a tela de entrada." | ✅ 28/10 |
| 1 | Tocar em ENTRAR com os campos vazios | "Validação básica antes de chamar o Firebase." | ✅ 28/10 |
| 2 | Digitar e-mail e senha da conta de demonstração → ENTRAR | "Autenticação real com Firebase Authentication." | ✅ 28/10 |
| 3 | Home: mostrar o cabeçalho e rolar a lista de partidas | "Partidas reais do Brasileirão vindas da API football-data.org. O saldo aparece como indisponível porque a carteira ainda não chegou à interface." | 🟡 lista ✅ 28/10; cabeçalho novo só em testes de widget |
| 4 | Puxar para atualizar; tocar em "MAIS PARTIDAS" | "A lista também se atualiza sozinha a cada 30 segundos." | ✅ 28/10 |
| 5 | Card "Desafio Rápido" → Desafiar | — | ✅ 28/10 |
| 6 | Criar Desafio: escolher uma partida e um valor | "Só aparecem partidas elegíveis: finalizadas, canceladas e adiadas ficam de fora. Amigos e saldo desta tela ainda são demonstrativos." | ✅ 28/10 |
| 7 | ENVIAR DESAFIO | "O app avisa que é demonstrativo: a gravação depende do backend de desafios, nosso próximo passo." | ✅ 28/10 |
| 8 | Avatar → Sair da conta → confirmar | "Logout real; o botão Voltar não retorna à Home." | ✅ 28/10 |
| 9 | (Opcional) Entrar de novo, fechar e reabrir o app | "A sessão é restaurada automaticamente." | ✅ 28/10 |

O backend novo (cadastro com username único, carteira e movimentações de BetCoins) **não aparece no app**. Se for mostrado, que seja como andamento técnico, por exemplo a saída dos testes no emulador, e não como funcionalidade.

## Evitar durante a demo

- Botão **CADASTRAR**: volta ao Login sem criar conta.
- Aba **Perfil**: no Firebase real, as Security Rules ainda não foram publicadas e a conta de demonstração pode não ter perfil. Mostrar só se o teste prévio exibir os dados corretamente; senão, explicar que ela foi validada nos emuladores.
- Botões **"Detalhes do Desafio"** em "Desafios Ativos": sem ação.
- O card **"SALDO DISPONÍVEL — 1.500 fichas"** da Criar Desafio é fixo: não apresentá-lo como saldo da conta.
- Escudo da **Chapecoense** aparece como quadrado branco na Home (observado em 28/10); se o jogo estiver na lista, não chamar atenção para ele.

## Contingência

| Problema | Ação |
|---|---|
| API sem resposta ou "Limite de requisições atingido" | Mostrar o tratamento de erro (é uma funcionalidade) e passar para o vídeo de contingência |
| Login falha por rede | Conferir a internet do emulador; se persistir, usar o vídeo |
| Emulador travado | Usar o vídeo; ter o aparelho físico como segunda opção |
