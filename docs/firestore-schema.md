# Firestore - Schema do BetFriends (MVP)

| Item | Valor |
|---|---|
| Versão | 2.0 — consolidação da **KAN-103** (proposta para revisão da equipe) |
| Versão anterior | 1.0 — estrutura inicial da KAN-17 (preservada no [Anexo A](#anexo-a---registro-da-kan-17)) |
| Base normativa | Plano Mestre v3.2 (§6 Regras de Negócio, §7 Máquina de Estados, §8 BetCoins, §9.3 Mapeamento, §11 Modelagem) e Documentação do Backlog Fase 8 |
| Código já alinhado | `lib/models/user_profile.dart` e `lib/data/firestore/user_profile_repository.dart` (KAN-32) |

## Como ler este documento

Cada decisão traz um marcador de origem:

| Marcador | Significado |
|---|---|
| **[PLANO]** | Definido no Plano Mestre v3.2 ou no backlog. Não muda sem revisão do Plano |
| **[KAN-17]** / **[KAN-32]** | Já existente no repositório |
| **[PROPOSTA]** | Recomendação da KAN-103. **Exige aprovação da equipe** (ver §9) antes de virar contrato definitivo |

Este documento é um **contrato de dados**. Ele não implementa regras de negócio, Security Rules, índices nem Functions. Essas tarefas pertencem às KANs indicadas em §10.

---

## 1 - Banco

| Item | Valor |
|---|---|
| Projeto Firebase | `betfriends-unirv-2026` |
| Database ID | `(default)` |
| Localização | `southamerica-east1` (mesma região das Callable Functions) |
| Modo / edição | `FIRESTORE_NATIVE` / `STANDARD` |

---

## 2 - Princípios do contrato

1. **Identidade pelo UID [PLANO RN-AUTH-006, KAN-32].** Todo relacionamento usa o UID do Firebase Authentication. Username e e-mail nunca são chave nem referência.
2. **O backend é a autoridade [PLANO RN-SEC-001/002/004, D-008].** Saldos, transações, estado sensível do desafio, resultado e vencedor só são escritos por Callable Functions ou jobs agendados, usando o Admin SDK. O app Flutter **lê** esses dados e **solicita** operações; nunca grava esses campos.
3. **Domínio independente do provedor [PLANO RNF-013].** `matches` guarda o modelo interno; nenhum JSON bruto da Football-Data é persistido.
4. **Datas em UTC [PLANO RN-MAT-005, KAN-17].** Toda data é `Timestamp`. Eventos de gravação usam `FieldValue.serverTimestamp()`. Datas de origem externa (ex.: início da partida) são convertidas para UTC antes de gravar. Texto formatado nunca é persistido.
5. **Valores de BetCoins são inteiros [PROPOSTA].** Todos os parâmetros do Plano são inteiros (1.000, 10, 500, 100). Usar `int`; nunca `double`.
6. **Nada é apagado no histórico [PLANO RN-HIS-001, RN-TRX].** Desafios encerrados e transações são permanentes.

### 2.1 - Convenção de nomes [PROPOSTA]

O Plano Mestre §11 descreve os campos em português (`nome`, `criadoEm`, `usuarioId`...), enquanto a KAN-17 e a KAN-32 já usam **camelCase em inglês** (`displayName`, `createdAt`, `userAId`, `challengerId`). Para não quebrar o código existente:

- **Regra geral:** campos em inglês camelCase, seguindo a KAN-17 e a KAN-32.
- **Exceção obrigatória:** os saldos usam os nomes do Plano §8.1, que declara essa nomenclatura "válida para documento, banco e código" (RN-PROF-003): **`saldoTotal`** e **`saldoReservado`**. `saldoDisponivel` é calculado e **não é persistido**.
- **Enums:** valores exatamente como no Plano (`PENDING`, `HOME_WIN`, `AGENDADA`, `INITIAL_BALANCE`...).

A correspondência completa com os nomes do Plano está em [§8](#8---correspondência-com-o-plano-mestre-11).

---

## 3 - Coleções

| Coleção | ID do documento | Escrita | Leitura pelo app | Origem |
|---|---|---|---|---|
| `users` | UID do Firebase Auth | Backend; o app só altera `displayName` (KAN-29) | Somente o próprio usuário | [PLANO] [KAN-17] |
| `usernames` | `usernameNormalized` | Backend | Nenhuma (consulta via Function) | **[PROPOSTA]** auxiliar da KAN-31 |
| `friendships` | `{uidMenor}_{uidMaior}` | Backend | Participantes | [PLANO] [KAN-17]; ID **[PROPOSTA]** |
| `matches` | `{provedor}_{externalMatchId}` | Backend (sincronização) | Qualquer usuário autenticado | [PLANO] [KAN-17]; ID **[PROPOSTA]** |
| `challenges` | ID automático | Backend | Participantes | [PLANO] [KAN-17] |
| `betCoinTransactions` | Determinístico (ver §3.6) | Backend, somente criação | Somente o dono | [PLANO] [KAN-17]; ID **[PROPOSTA]** |

As cinco coleções oficiais continuam as da KAN-17 (`FirestoreCollections`). `usernames` é a única coleção nova proposta, necessária para garantir unicidade sob concorrência (ver §3.2).

---

### 3.1 - `users/{uid}`

Conta, perfil e carteira do usuário. O Plano §11 define `User` como "a conta e a carteira do usuário".

| Campo | Tipo | Obrigatório | Mutabilidade | Escrito por | Origem / regra |
|---|---|---|---|---|---|
| *(ID do documento)* | string (UID) | sim | imutável | backend | [PLANO] RN-AUTH-006; [KAN-32] |
| `displayName` | string, 1–60 caracteres após `trim` | sim | **atualizável** | backend no cadastro; app na KAN-29 | [PLANO] RN-AUTH-004; [KAN-32] |
| `username` | string, como digitado | sim | **imutável** | backend | [PLANO] RN-AUTH-004, D-011; [KAN-32] |
| `usernameNormalized` | string (§3.2) | sim | **imutável** | backend | [PLANO] RN-AUTH-003; [KAN-32] |
| `email` | string | sim | imutável pelo app | backend | [PLANO] RN-PROF-001; [KAN-32]. Privado (RN-PROF-002) |
| `saldoTotal` | int ≥ 0 | sim | só backend | backend | [PLANO] §8.1, RNF-007 |
| `saldoReservado` | int ≥ 0 e ≤ `saldoTotal` | sim | só backend | backend | [PLANO] §8.1 |
| `lastRecoveryBonusAt` | Timestamp \| null | sim (null até o 1º bônus) | só backend | backend | [PLANO] §11 `ultimoBonusRecuperacao`, RN-BET-008 |
| `createdAt` | Timestamp (servidor) | sim | imutável | backend | [PLANO] RN-PROF-001; [KAN-32] |
| `updatedAt` | Timestamp (servidor) | sim | a cada alteração | backend / app (KAN-29) | [KAN-17]; [KAN-32] |

**Invariantes (KAN-73):**
- `saldoTotal ≥ 0`, `saldoReservado ≥ 0`, `saldoReservado ≤ saldoTotal`, portanto `saldoDisponivel = saldoTotal − saldoReservado ≥ 0` (RNF-007, RN-BET-004).
- Toda alteração de `saldoTotal` ou `saldoReservado` ocorre **na mesma transação Firestore** que cria a(s) `betCoinTransactions` correspondente(s) (RN-TRX-001, RN-SYS-001).

**Exemplo fictício:**

```json
// users/aBc123UidFicticio
{
  "displayName": "Lucas Almeida",
  "username": "Lucas10",
  "usernameNormalized": "lucas10",
  "email": "lucas@example.com",
  "saldoTotal": 1000,
  "saldoReservado": 0,
  "lastRecoveryBonusAt": null,
  "createdAt": "<Timestamp 2026-10-28T13:00:00Z>",
  "updatedAt": "<Timestamp 2026-10-28T13:00:00Z>"
}
```

#### 3.1.1 - Por que a carteira fica em `users/{uid}` [PROPOSTA]

| Critério | Carteira em `users/{uid}` (recomendado) | Documento separado (`wallets/{uid}`) |
|---|---|---|
| Plano Mestre §11 | Coincide: `User` contém os saldos | Exige ajustar o Plano |
| Atomicidade | Uma leitura e uma escrita por usuário na transação | Duas leituras por usuário |
| Concorrência | O documento do usuário serializa as operações do mesmo usuário (ver §5.2) | Precisa de outro ponto de serialização |
| Privacidade (RN-PROF-002) | Exige que **ninguém além do dono leia** `users/{uid}` | Permite um perfil mais aberto |
| Coleções | Mantém as 5 oficiais | Cria a 6ª/7ª coleção |

**Consequência:** como `users/{uid}` contém e-mail e saldos, **só o próprio usuário lê o documento**. Busca de usuários (KAN-33), lista de amigos (KAN-38) e nomes exibidos em desafios devem obter `displayName`/`username` de outra forma. Opções a decidir na KAN-22/KAN-33:
- **(a, recomendada)** via Callable Function que devolve apenas campos públicos;
- **(b)** cópia desnormalizada de `displayName`/`username` nos documentos de `friendships` e `challenges` (ver campos opcionais em §3.3 e §3.5).

#### 3.1.2 - Criação do documento [PROPOSTA]

KAN-25 exige "identidade consistente sem perfil parcial", e KAN-72 exige carteira inicial idempotente. Por isso a criação de `users/{uid}` deve ocorrer **numa única transação no backend**, por uma Callable Function (ex.: `createUserProfile`), que:

1. lê `users/{uid}` — se já existir, retorna o perfil existente (idempotência);
2. lê `usernames/{usernameNormalized}` — se existir com outro UID, falha com `already-exists`;
3. cria `usernames/{usernameNormalized}`;
4. cria `users/{uid}` com `saldoTotal = 1000`, `saldoReservado = 0`;
5. cria `betCoinTransactions/{uid}_INITIAL_BALANCE` (§3.6).

**Implementação (KAN-31):** Callable `createUserProfile` (`functions/src/perfil/`), que segue os passos acima numa única transação. UID e e-mail vêm do token do Firebase Authentication. Erros devolvidos ao app: `already-exists` (somente username indisponível), `invalid-argument` (nome ou username fora do formato), `failed-precondition` (usuário já tem perfil com outro username ou não tem e-mail); `details.motivo` traz o código do domínio. Reenviar o mesmo cadastro devolve `criado: false` sem gravar. Ligar a tela de cadastro a esta função é da KAN-25.

No app, a chamada é feita por `UserProfileService.criarPerfilDoUsuarioAtual` (KAN-32); ver [§7](#7---compatibilidade-com-o-código-existente).

---

### 3.2 - `usernames/{usernameNormalized}` [PROPOSTA — auxiliar da KAN-31]

O Firestore não tem restrição de unicidade por campo. Uma consulta `where('usernameNormalized', '==', x)` seguida de escrita **não é segura** sob concorrência, porque duas criações simultâneas podem não enxergar uma à outra. A forma padrão é reservar o valor como **ID de documento**: dentro de uma transação, a criação de um documento com ID já existente falha.

| Campo | Tipo | Obrigatório | Mutabilidade | Descrição |
|---|---|---|---|---|
| *(ID)* | string | sim | imutável | `usernameNormalized` |
| `uid` | string | sim | imutável | Dono do username |
| `createdAt` | Timestamp (servidor) | sim | imutável | — |

**Normalização (decidida na KAN-31):**
- `usernameNormalized = username.trim().toLowerCase()`, o que atende RN-AUTH-003 (`Simon` = `simon`).
- Formato de `username`: 3 a 20 caracteres, apenas `a-z`, `A-Z`, `0-9` e `_`. Isso evita ambiguidades de acentos e de Unicode sem exigir normalização adicional.
- Como o username é imutável (D-011), o documento nunca é movido nem apagado.

Leitura: nenhuma pelo app; a verificação de disponibilidade é feita pela Function.

---

### 3.3 - `friendships/{friendshipId}`

| Campo | Tipo | Obrigatório | Mutabilidade | Descrição / regra |
|---|---|---|---|---|
| *(ID)* | string `{uidMenor}_{uidMaior}` | sim | imutável | **[PROPOSTA]** UIDs ordenados lexicograficamente |
| `userAId` | string (UID) | sim | imutável | Menor UID do par [KAN-17] |
| `userBId` | string (UID) | sim | imutável | Maior UID do par [KAN-17] |
| `participants` | array\<string\> `[userAId, userBId]` | sim | imutável | **[PROPOSTA]** permite `array-contains` para listar amizades de um usuário |
| `requesterId` | string (UID) | sim | atualizável apenas ao reabrir após `REJECTED` | **[PROPOSTA]** quem enviou a solicitação ativa |
| `status` | enum `PENDING` \| `ACCEPTED` \| `REJECTED` | sim | backend | [PLANO] §11 |
| `createdAt` | Timestamp | sim | imutável | [PLANO] [KAN-17] |
| `respondedAt` | Timestamp \| null | não | backend | **[PROPOSTA]** aceite ou recusa |
| `updatedAt` | Timestamp | sim | backend | [KAN-17] |

**Integridade:**
- **ID determinístico** impede duas relações para o mesmo par (RN-FRD-003, RN-FRD-004, KAN-40). Criar dentro de uma transação que lê o ID antes.
- `userAId ≠ userBId` (RN-FRD-002).
- **Solicitação cruzada (RN-FRD-005, KAN-41):** se B solicita A e o documento já está `PENDING` com `requesterId = A`, a mesma transação muda para `ACCEPTED`. O resultado é uma única relação aceita.
- **Recusa:** `REJECTED` não é "solicitação ativa" (RN-FRD-003). Uma nova solicitação reutiliza o mesmo documento, voltando para `PENDING` com novo `requesterId`. **[PROPOSTA]**
- **Remoção (RN-FRD-006):** o Plano não prevê estado `REMOVED`. **[PROPOSTA]** a remoção **apaga** o documento, na mesma operação que cancela os desafios `PENDING` entre os dois e libera as reservas (RN-FRD-007). Desafios aceitos continuam (RN-FRD-008), porque `challenges` referencia UIDs, não a amizade.
- Desafio só pode ser criado se `friendships/{par}` existir com `ACCEPTED` (RN-FRD-001, RN-CHL-002).

Campos opcionais de exibição (se a opção (b) de §3.1.1 for escolhida): `userADisplayName`, `userBDisplayName`, `userAUsername`, `userBUsername`.

```json
// friendships/aBc123UidFicticio_xYz789UidFicticio
{
  "userAId": "aBc123UidFicticio",
  "userBId": "xYz789UidFicticio",
  "participants": ["aBc123UidFicticio", "xYz789UidFicticio"],
  "requesterId": "xYz789UidFicticio",
  "status": "ACCEPTED",
  "createdAt": "<Timestamp 2026-10-28T13:05:00Z>",
  "respondedAt": "<Timestamp 2026-10-28T13:10:00Z>",
  "updatedAt": "<Timestamp 2026-10-28T13:10:00Z>"
}
```

---

### 3.4 - `matches/{matchId}`

Modelo de domínio da partida, alimentado **somente** pela sincronização do backend (RF-008, RN-CACHE-004). Campos conforme o Plano §11.

**Implementação (KAN-46):** `functions/src/partidas/match.ts` (modelo `Match`, enums de status e resultado, validação e ID `{providerKey}_{externalMatchId}`) e `functions/src/partidas/matchFirestore.ts` (`gravarMatchNaTransacao` cria ou atualiza o mesmo documento, preservando `originalStartsAtUtc` e `createdAt`; a leitura recusa status fora do domínio). O `providerKey` não é gravado: é o prefixo do ID.

| Campo | Tipo | Obrigatório | Descrição / regra |
|---|---|---|---|
| *(ID)* | string | sim | **[PROPOSTA]** `{providerKey}_{externalMatchId}`, ex.: `footballdata_537123`. Ver nota abaixo |
| `provider` | string | sim | [PLANO] Ex.: `football-data.org` |
| `externalMatchId` | string | sim | [PLANO] ID da partida no provedor, guardado como texto |
| `competitionCode` | string | sim | [PLANO] `BSA` |
| `season` | int | sim | [PLANO] `2026` |
| `matchday` | int \| null | não | [PLANO] Rodada |
| `startsAtUtc` | Timestamp | sim | [PLANO] Início oficial **mais recente** (RN-MAT-006). Base do corte de 5 min (RN-MAT-004) |
| `originalStartsAtUtc` | Timestamp | sim | **[PROPOSTA]** Primeiro horário sincronizado. Necessário para RN-MAT-007/008 (adiamento ≤ ou > 7 dias "em relação à data original"); não consta do §11 do Plano |
| `status` | enum (abaixo) | sim | [PLANO] Status **do domínio**, nunca o do provedor |
| `homeTeam` | map `{ externalId: string, name: string, shortName: string \| null }` | sim | [PLANO] "identificador externo e nome". **Sem escudo** (RNF-012) |
| `awayTeam` | map, idem | sim | [PLANO] |
| `homeScore` | int \| null | não | [PLANO] Placar final, para auditoria |
| `awayScore` | int \| null | não | [PLANO] |
| `result` | enum `HOME_WIN` \| `DRAW` \| `AWAY_WIN` \| null | não | [PLANO] Nulo até `FINALIZADA` (RN-RES-003) |
| `providerLastUpdated` | Timestamp \| null | não | [PLANO] Marca de atualização do provedor |
| `syncedAt` | Timestamp (servidor) | sim | [PLANO] Última sincronização do BetFriends; também exibido como "última atualização" (RN-CACHE-002) |
| `createdAt` | Timestamp (servidor) | sim | [KAN-17] Primeira sincronização |

**Enum `status` [PLANO §9.3 e §11]:**

| Domínio | Provedor (Football-Data v4) | Efeito |
|---|---|---|
| `AGENDADA` | `SCHEDULED`, `TIMED` | Elegível para desafio até `startsAtUtc − 5 min` |
| `EM_ANDAMENTO` | `IN_PLAY`, `PAUSED` | Bloqueia novos desafios; aceitos → `IN_PROGRESS` |
| `FINALIZADA` | `FINISHED` | Grava placar e `result`; dispara a liquidação |
| `ADIADA` | `POSTPONED` | RN-MAT-007 a 009 |
| `CANCELADA` | `CANCELLED` | Cancela desafios e devolve reservas (RN-MAT-010/011) |
| `SUSPENSA` | `SUSPENDED` | Não liquida (RN-MAT-015) |
| `REVISAO_NECESSARIA` | `AWARDED` | Não liquida automaticamente (RN-MAT-016) |

**Resultado [PLANO §9.3]:** `HOME_TEAM` → `HOME_WIN`; `DRAW` → `DRAW`; `AWAY_TEAM` → `AWAY_WIN`.

**Nota sobre o ID [PROPOSTA]:** o Plano diz que o `id` é "identificador interno do Firestore, independente do provedor". Um ID automático atende literalmente, mas obriga a sincronização a consultar `provider + externalMatchId` antes de gravar e permite duplicatas se duas execuções rodarem ao mesmo tempo (KAN-49 exige "não cria duplicados"). O ID determinístico torna a sincronização idempotente. Os desafios continuam referenciando só `matchId`, então o domínio não depende do formato do provedor. **Decisão pendente** (§9, D-SCH-05).

```json
// matches/footballdata_537123
{
  "provider": "football-data.org",
  "externalMatchId": "537123",
  "competitionCode": "BSA",
  "season": 2026,
  "matchday": 32,
  "startsAtUtc": "<Timestamp 2026-10-29T22:30:00Z>",
  "originalStartsAtUtc": "<Timestamp 2026-10-29T22:30:00Z>",
  "status": "AGENDADA",
  "homeTeam": { "externalId": "1765", "name": "Fluminense FC", "shortName": "Fluminense" },
  "awayTeam": { "externalId": "6684", "name": "SC Internacional", "shortName": "Internacional" },
  "homeScore": null,
  "awayScore": null,
  "result": null,
  "providerLastUpdated": "<Timestamp 2026-10-28T12:00:00Z>",
  "syncedAt": "<Timestamp 2026-10-28T12:05:00Z>",
  "createdAt": "<Timestamp 2026-10-01T09:00:00Z>"
}
```

(IDs e nomes do exemplo são ilustrativos.)

---

### 3.5 - `challenges/{challengeId}`

| Campo | Tipo | Obrigatório | Mutabilidade | Origem / regra |
|---|---|---|---|---|
| *(ID)* | string (automático) | sim | imutável | [PLANO] |
| `challengerId` | string (UID) | sim | imutável | [PLANO] `criadorId`; [KAN-17] |
| `challengedId` | string (UID) | sim | imutável | [PLANO] `desafiadoId`; [KAN-17] |
| `participants` | array\<string\> `[challengerId, challengedId]` | sim | imutável | **[PROPOSTA]** consultas de histórico (KAN-89) |
| `matchId` | string (ID em `matches`) | sim | imutável | [PLANO] [KAN-17] |
| `challengerPrediction` | enum `HOME_WIN` \| `DRAW` \| `AWAY_WIN` | sim | imutável | [PLANO] `palpiteCriador`; RN-PRD-001 |
| `challengedPrediction` | mesmo enum \| null | não (null até o aceite) | definido uma vez no aceite | [PLANO] `palpiteDesafiado`; RN-PRD-003: ≠ `challengerPrediction` |
| `amount` | int, 10 a 500 | sim | imutável | [PLANO] `valorBetCoins`; RN-BET-002/003; [KAN-17] |
| `status` | enum (abaixo) | sim | backend | [PLANO] §7 |
| `winnerId` | string (UID) \| null | não | definido uma vez na finalização | [PLANO] `vencedorId`; nulo em empate e cancelamento |
| `settledResult` | enum `HOME_WIN` \| `DRAW` \| `AWAY_WIN` \| null | não | definido uma vez | **[PROPOSTA]** resultado usado na liquidação; preserva RN-RES-008 mesmo que `matches.result` mude depois |
| `cancelReason` | enum \| null | não | definido uma vez | **[PROPOSTA]** `CREATOR`, `FRIENDSHIP_REMOVED`, `MATCH_CANCELLED`, `MATCH_POSTPONED` (motivos listados no Plano §7) |
| `createdAt` | Timestamp | sim | imutável | [PLANO] `criadoEm` |
| `acceptedAt` | Timestamp \| null | não | uma vez | [PLANO] `aceitoEm` |
| `startedAt` | Timestamp \| null | não | uma vez | [PLANO] `iniciadoEm` |
| `finishedAt` | Timestamp \| null | não | uma vez | [PLANO] `finalizadoEm`; **[PROPOSTA]** preenchido em qualquer estado terminal, para ordenar o histórico |
| `updatedAt` | Timestamp | sim | a cada transição | [KAN-17] |

**Não é persistido:** prazo de expiração. Ele é sempre derivado de `matches.startsAtUtc − 5 min`, porque o horário pode mudar (RN-MAT-006). A expiração (KAN-65) consulta desafios `PENDING` por `matchId`.

**Enum `status` e transições [PLANO §7] — sem estados adicionais:**

| Estado | Terminal | Próximos |
|---|---|---|
| `PENDING` | não | `ACCEPTED`, `REJECTED`, `EXPIRED`, `CANCELLED` |
| `ACCEPTED` | não | `IN_PROGRESS`, `CANCELLED` |
| `IN_PROGRESS` | não | `WAITING_RESULT`, `CANCELLED` |
| `WAITING_RESULT` | não | `FINISHED`, `CANCELLED` |
| `FINISHED` | sim | — |
| `REJECTED` | sim | — |
| `EXPIRED` | sim | — |
| `CANCELLED` | sim | — |

"Desafio ativo" (RN-CHL-010/011, KAN-64) = estados **não terminais**.

**Integridade:**
- `challengerId ≠ challengedId`; amizade `ACCEPTED` no momento da criação (RN-CHL-002).
- `matches/{matchId}.status == AGENDADA` e `agora < startsAtUtc − 5 min` na criação **e** no aceite (RN-MAT-003/004).
- No máximo um desafio ativo por usuário e partida (RN-CHL-011). Ver como garantir sob concorrência em §5.2.
- Depois de `ACCEPTED`, `matchId`, `amount`, palpites e participantes não mudam (RN-CHL-024).
- `FINISHED` só é gravado depois que todas as transações da liquidação existirem, na mesma transação (KAN-85, RN-RES-009).
- Documentos nunca são apagados (RN-HIS-001).

```json
// challenges/Ch4ll3ng3IdFicticio
{
  "challengerId": "aBc123UidFicticio",
  "challengedId": "xYz789UidFicticio",
  "participants": ["aBc123UidFicticio", "xYz789UidFicticio"],
  "matchId": "footballdata_537123",
  "challengerPrediction": "HOME_WIN",
  "challengedPrediction": "AWAY_WIN",
  "amount": 100,
  "status": "FINISHED",
  "winnerId": null,
  "settledResult": "DRAW",
  "cancelReason": null,
  "createdAt": "<Timestamp 2026-10-28T14:00:00Z>",
  "acceptedAt": "<Timestamp 2026-10-28T15:00:00Z>",
  "startedAt": "<Timestamp 2026-10-29T22:30:00Z>",
  "finishedAt": "<Timestamp 2026-10-30T00:40:00Z>",
  "updatedAt": "<Timestamp 2026-10-30T00:40:00Z>"
}
```

(Exemplo de empate estrutural: nenhum dos dois acertou, `winnerId = null`, e cada um recebe `REFUND`.)

---

### 3.6 - `betCoinTransactions/{transactionId}`

Ledger auditável. Uma transação é **criada uma vez e nunca alterada nem apagada**.

**Implementação (KAN-79):** `functions/src/betcoins/transacoes.ts` (tipos, efeitos, IDs e validação) e `functions/src/betcoins/transacoesTransacao.ts` (`registrarMovimentacoesNaTransacao` grava saldos e transações na mesma transação Firestore; `ledgerDoSaldoInicial` registra o `INITIAL_BALANCE` da KAN-72). Reexecutar uma operação já registrada não grava nada; se só parte dela existir, a operação é recusada como `ledger-inconsistente`.

| Campo | Tipo | Obrigatório | Origem / regra |
|---|---|---|---|
| *(ID)* | string determinística | sim | **[PROPOSTA]** chave de idempotência (tabela abaixo) |
| `userId` | string (UID) | sim | [PLANO] `usuarioId`; [KAN-17] |
| `challengeId` | string \| null | não | [PLANO] obrigatório para `RESERVE`, `RELEASE`, `WIN`, `LOSS`, `REFUND` |
| `type` | enum (abaixo) | sim | [PLANO] RN-TRX-002 |
| `amount` | int > 0 | sim | [PLANO] `valor`. **[PROPOSTA]** sempre positivo; o efeito vem do `type` |
| `balanceBefore` | map `{ saldoTotal: int, saldoReservado: int }` | sim | [PLANO] `saldoAnterior`. **[PROPOSTA]** guarda os dois saldos (ver nota) |
| `balanceAfter` | map `{ saldoTotal: int, saldoReservado: int }` | sim | [PLANO] `saldoPosterior` |
| `createdAt` | Timestamp (servidor) | sim | [PLANO] `criadoEm` |
| `metadata` | map \| null | não | [KAN-17] Dados auxiliares não financeiros (ex.: `matchId`); nunca segredos |

**Nota sobre `balanceBefore`/`balanceAfter` [PROPOSTA]:** o Plano pede `saldoAnterior` e `saldoPosterior` para "reconstruir integralmente a movimentação" (RN-TRX-003). Porém `RESERVE`, `RELEASE` e `REFUND` **não alteram o saldo total**, só o reservado (§8.3). Guardar apenas um número não reconstruiria essas movimentações. Guardar os dois saldos resolve sem criar conceito novo.

**Tipos e efeitos [PLANO §8.3, RN-TRX-004 a 008]:**

| `type` | `saldoTotal` | `saldoReservado` | Quando | `challengeId` |
|---|---|---|---|---|
| `INITIAL_BALANCE` | +1.000 | 0 | Cadastro | null |
| `RESERVE` | 0 | +amount | Criação ou aceite do desafio | sim |
| `RELEASE` | 0 | −amount | Vitória (própria reserva), recusa, cancelamento, expiração | sim |
| `WIN` | +amount | 0 | Vitória (valor do adversário) | sim |
| `LOSS` | −amount | −amount | Derrota | sim |
| `REFUND` | 0 | −amount | Empate | sim |
| `RECOVERY_BONUS` | +100 | 0 | Recuperação (RN-BET-007 a 011) | null |

Verificação: vitória = `RELEASE` + `WIN` → reservado −valor, total +valor; derrota = `LOSS` → reservado −valor, total −valor. Ambas conferem com a tabela do Plano §8.3.

**ID determinístico (idempotência) [PROPOSTA]:**

| Movimentação | ID |
|---|---|
| Saldo inicial | `{uid}_INITIAL_BALANCE` |
| Reserva / liberação / vitória / derrota / reembolso | `{challengeId}_{uid}_{TYPE}` |
| Bônus de recuperação | `{uid}_RECOVERY_BONUS_{yyyyMMddHH}`, hora UTC da concessão; a regra de 24 h (RN-BET-008) é validada por `users.lastRecoveryBonusAt` |

Um usuário tem no máximo um `RESERVE` e uma liquidação por desafio, então `{challengeId}_{uid}_{TYPE}` é único. Na reexecução de um job (KAN-65, KAN-85), a transação Firestore lê esse ID: se já existir, a operação não é repetida.

```json
// betCoinTransactions/Ch4ll3ng3IdFicticio_aBc123UidFicticio_RESERVE
{
  "userId": "aBc123UidFicticio",
  "challengeId": "Ch4ll3ng3IdFicticio",
  "type": "RESERVE",
  "amount": 100,
  "balanceBefore": { "saldoTotal": 1000, "saldoReservado": 0 },
  "balanceAfter":  { "saldoTotal": 1000, "saldoReservado": 100 },
  "createdAt": "<Timestamp 2026-10-28T14:00:00Z>",
  "metadata": { "matchId": "footballdata_537123" }
}
```

---

## 4 - Relacionamentos

```text
users/{uid} ─1──n─ betCoinTransactions.userId
     │  └─1──1─ usernames/{usernameNormalized}.uid
     ├─n──n─ friendships (userAId, userBId)
     └─1──n─ challenges (challengerId, challengedId)
matches/{matchId} ─1──n─ challenges.matchId
challenges/{challengeId} ─1──n─ betCoinTransactions.challengeId
```

Todas as referências são IDs em `string`, não `DocumentReference`, para manter o modelo simples entre Dart e TypeScript. **[PROPOSTA]**

---

## 5 - Integridade, atomicidade e autoridade

### 5.1 - Quem escreve o quê

| Dado | App Flutter | Backend (Functions/Scheduler) |
|---|---|---|
| `users.displayName` | atualiza (KAN-29) | cria |
| demais campos de `users`, `usernames` | — | cria e atualiza |
| `friendships` | — (solicita via Function) | cria, atualiza, apaga |
| `matches` | — | sincroniza |
| `challenges` | — (solicita via Function) | cria e transiciona |
| `betCoinTransactions` | — | só cria |

O app nunca grava saldo, transação, estado de desafio, resultado ou vencedor (RN-SEC-001/002/004). A lista de operações que obrigatoriamente usam Callable Functions está no Plano §6.10.

### 5.2 - Atomicidade e concorrência

- Toda operação financeira é **uma transação Firestore no backend** que lê `users/{uid}` de cada participante, valida o saldo, atualiza os saldos e cria as transações (RN-SYS-001).
- Como reservar saldo sempre atualiza `users/{uid}`, duas operações simultâneas do **mesmo usuário** conflitam nesse documento e uma delas é repetida pelo Firestore. Isso impede reservar acima do disponível (RN-SYS-002) e permite checar "um desafio ativo por partida" (RN-CHL-011) dentro da mesma transação, consultando `challenges` por `matchId` e participante. **[PROPOSTA — validar em teste de concorrência na KAN-64/KAN-74]**
- Limite do Firestore: até 500 escritas por transação, o que basta para o MVP (liquidação = 1 desafio, 2 usuários, até 3 transações).

### 5.3 - Datas

| Situação | Como gravar |
|---|---|
| Momento da gravação | `FieldValue.serverTimestamp()` |
| Data externa (início da partida) | `Timestamp.fromDate(date.toUtc())` / `Timestamp.fromDate(new Date(isoUtc))` |
| Exibição | Converter para o fuso local só na UI |
| Proibido | Texto formatado (ex.: `"01/10/2026 15:30"`) |

---

## 6 - Índices recomendados

**Não aplicados.** `firestore.indexes.json` continua vazio; cada índice entra junto com a consulta que o usa, na KAN responsável.

| Coleção | Campos | Consulta | KAN |
|---|---|---|---|
| `betCoinTransactions` | `userId ASC`, `createdAt DESC` | Extrato do usuário | KAN-70, KAN-79 |
| `betCoinTransactions` | `challengeId ASC`, `createdAt ASC` | Movimentações de um desafio | KAN-61, KAN-91 |
| `challenges` | `challengedId ASC`, `status ASC`, `createdAt DESC` | Desafios recebidos | KAN-56 |
| `challenges` | `challengerId ASC`, `status ASC`, `createdAt DESC` | Desafios enviados | KAN-57 |
| `challenges` | `participants CONTAINS`, `status ASC`, `finishedAt DESC` | Histórico | KAN-89 |
| `challenges` | `matchId ASC`, `status ASC` | Expiração, início, liquidação | KAN-65 a KAN-68, KAN-82 |
| `friendships` | `participants CONTAINS`, `status ASC` | Amigos e solicitações | KAN-35, KAN-38 |
| `matches` | `competitionCode ASC`, `season ASC`, `startsAtUtc ASC` | Próximas partidas | KAN-42 |
| `matches` | `status ASC`, `startsAtUtc ASC` | Janelas da sincronização | KAN-50 |

---

## 7 - Compatibilidade com o código existente

| Código | Situação |
|---|---|
| `UserProfile` (KAN-32): `displayName`, `username`, `usernameNormalized`, `email`, `createdAt`, `updatedAt` | ✅ **Compatível.** Todos os campos foram mantidos com os mesmos nomes e tipos. `fromMap` ignora campos extras (saldos, `lastRecoveryBonusAt`), então documentos completos continuam legíveis. O UID continua sendo o ID do documento e não é gravado nos campos |
| `UserProfile.toMap()` não grava saldos | ✅ Coerente com §5.1 |
| Criação de `users/{uid}` pelo app | ✅ **Resolvido na KAN-32.** `FirestoreUserProfileRepository.criar` foi removido; `UserProfileService.criarPerfilDoUsuarioAtual` chama a Callable `createUserProfile` (KAN-31), que cria perfil, username e carteira |
| `UserProfileService.criarPerfilDoUsuarioAtual` recebia `usernameNormalized` do chamador | ✅ **Resolvido na KAN-32.** O parâmetro foi removido; a normalização é só do backend. Ligar a tela de cadastro ao serviço fica na KAN-25 |
| `FirestoreCollections` (5 coleções) | ✅ Compatível; `usernames` não é lida pelo app (§3.2), então não precisa de constante no Flutter |
| `PartidaModel` (Flutter) | ⚠️ Usa o formato do provedor; será substituído por um modelo baseado em `matches` (KAN-46/KAN-52). Fora do escopo |
| `firestore.rules` (*deny-all*) | ✅ Compatível; as regras de §5.1 serão escritas na KAN-22 |

---

## 8 - Correspondência com o Plano Mestre §11

| Entidade | Plano §11 | Este schema |
|---|---|---|
| User | `id` | ID do documento (UID) |
| | `nome` | `displayName` |
| | `username`, `email` | `username`, `email` (+ `usernameNormalized`) |
| | `saldoTotal`, `saldoReservado` | **iguais** |
| | `ultimoBonusRecuperacao` | `lastRecoveryBonusAt` |
| | `criadoEm` | `createdAt` (+ `updatedAt`) |
| Friendship | `usuarioAId`, `usuarioBId` | `userAId`, `userBId` (+ `participants`, `requesterId`) |
| | `status`, `criadoEm` | `status`, `createdAt` (+ `respondedAt`, `updatedAt`) |
| Match | campos do §11 | iguais (+ `originalStartsAtUtc`, `createdAt`) |
| Challenge | `criadorId`, `desafiadoId` | `challengerId`, `challengedId` |
| | `palpiteCriador`, `palpiteDesafiado` | `challengerPrediction`, `challengedPrediction` |
| | `valorBetCoins`, `vencedorId` | `amount`, `winnerId` |
| | `criadoEm`, `aceitoEm`, `iniciadoEm`, `finalizadoEm` | `createdAt`, `acceptedAt`, `startedAt`, `finishedAt` (+ `participants`, `settledResult`, `cancelReason`, `updatedAt`) |
| BetCoinTransaction | `usuarioId`, `challengeId`, `tipo`, `valor` | `userId`, `challengeId`, `type`, `amount` |
| | `saldoAnterior`, `saldoPosterior` | `balanceBefore`, `balanceAfter` (mapas com os dois saldos) |
| | `criadoEm` | `createdAt` (+ `metadata`) |

---

## 9 - Decisões que exigem aprovação

| ID | Decisão proposta | Alternativa | Impacto se rejeitada | Aprovar com |
|---|---|---|---|---|
| D-SCH-01 | Campos em inglês, com exceção de `saldoTotal`/`saldoReservado` (RN-PROF-003) | Tudo em português conforme §11 (exige alterar a KAN-32) ou tudo em inglês (exige ajustar RN-PROF-003) | Renomeações em código e documentação | Equipe |
| D-SCH-02 | Carteira em `users/{uid}`, leitura só pelo dono | `wallets/{uid}` separado | Muda KAN-72/73/74 e as rules | Matheus (backend) |
| D-SCH-03 | Coleção auxiliar `usernames/{usernameNormalized}` e normalização `trim + lowercase` | Outra estratégia de unicidade | Muda KAN-31 | Matheus, Pedro |
| D-SCH-04 | Criação de `users/{uid}` por Callable Function atômica | Criação pelo cliente com rules restritas (sem carteira) e carteira em seguida | Risco de perfil parcial (KAN-25); altera `FirestoreUserProfileRepository.criar` | Equipe; depende da habilitação das Functions (plano Blaze) |
| D-SCH-05 | ID determinístico em `matches` | ID automático + consulta por `externalMatchId` | Sincronização menos idempotente (KAN-49) | Matheus |
| D-SCH-06 | `originalStartsAtUtc` em `matches` | Calcular adiamento sem a data original (não atende RN-MAT-007) | RN-MAT-007/008 sem base | Matheus, Guilherme |
| D-SCH-07 | `balanceBefore`/`balanceAfter` com os dois saldos | Só `saldoTotal` | RESERVE/RELEASE/REFUND não reconstruíveis | Matheus |
| D-SCH-08 | IDs determinísticos em `friendships` e `betCoinTransactions` | IDs automáticos + consultas | Duplicidade sob concorrência (KAN-40, KAN-65, KAN-85) | Matheus, Guilherme |
| D-SCH-09 | Remoção de amizade apaga o documento | Estado novo (ex.: `REMOVED`) — não previsto no Plano | — | Guilherme |
| D-SCH-10 | Leitura de nome/username de outros usuários via Callable | Desnormalizar em `friendships`/`challenges` | Muda KAN-33/38/56/57 | Kauê, Guilherme |
| D-SCH-11 | Convite `PENDING` conta como "desafio ativo" também para o **desafiado** (RN-CHL-011) | Contar só a partir do aceite | Plano não detalha; afeta KAN-64 | Guilherme |

---

## 10 - Rastreabilidade com as KANs

| KAN | O que este schema entrega |
|---|---|
| KAN-22 Security Rules | Matriz de escrita/leitura (§3, §5.1) |
| KAN-25 Criar conta | Fluxo atômico de criação (§3.1.2) |
| KAN-29 Alterar nome | `displayName` é o único campo editável pelo app |
| KAN-31 Username único | `usernames/{usernameNormalized}` e normalização (§3.2) |
| KAN-32 Perfil por UID | Campos mantidos; compatibilidade (§7) |
| KAN-34 a KAN-41 Amizades | ID determinístico, estados, cruzadas, remoção (§3.3) |
| KAN-46, KAN-47, KAN-48, KAN-49 Match | Campos, enums de status e resultado, ID idempotente (§3.4) |
| KAN-51 Corte de 5 min | `startsAtUtc` (§3.4) |
| KAN-62 a KAN-68 Challenge | Campos, estados, integridade, expiração derivada (§3.5) |
| KAN-72, KAN-73, KAN-74 a KAN-80 BetCoins | Saldos, invariantes, tipos, idempotência (§3.1, §3.6, §5.2) |
| KAN-82 a KAN-87 Liquidação | `settledResult`, `winnerId`, IDs idempotentes (§3.5, §3.6) |
| KAN-88 a KAN-91 Histórico | `participants`, `finishedAt`, índices (§3.5, §6) |

---

## 11 - Fora do escopo da KAN-103

Implementação de modelos Dart/TypeScript, Security Rules, índices em `firestore.indexes.json`, Callable Functions, migração de dados e qualquer escrita no Firebase. Nenhum desses itens foi alterado.

---

## Anexo A - Registro da KAN-17

Conteúdo da versão 1.0, mantido como histórico.

### A.1 - Estrutura inicial (KAN-17)

| Coleção | Campos previstos na KAN-17 | Situação na v2.0 |
|---|---|---|
| `users` | `displayName`, `username`, `usernameNormalized`, `email`, `createdAt`, `updatedAt` | Mantidos; acrescentados saldos e `lastRecoveryBonusAt` |
| `friendships` | `userAId`, `userBId`, `status`, `createdAt`, `updatedAt` | Mantidos; acrescentados `participants`, `requesterId`, `respondedAt` |
| `matches` | `externalId`, `homeTeam`, `awayTeam`, `utcDate`, `status`, `result`, `createdAt`, `updatedAt` | `externalId` → `externalMatchId`; `utcDate` → `startsAtUtc`; `updatedAt` → `syncedAt` (Plano §11); demais campos do Plano acrescentados |
| `challenges` | `challengerId`, `challengedId`, `matchId`, `amount`, `status`, `createdAt`, `updatedAt` | Mantidos; acrescentados palpites, `winnerId` e datas do Plano |
| `betCoinTransactions` | `userId`, `type`, `amount`, `challengeId`, `createdAt`, `metadata` | Mantidos; acrescentados `balanceBefore`/`balanceAfter` |

### A.2 - Validação técnica da KAN-17

Durante a KAN-17, uma consulta técnica do app Flutter ao Firestore alcançou o banco real e retornou `PERMISSION_DENIED`, como esperado pelas regras *deny-all*. Isso confirmou que o app está conectado ao projeto correto, que o banco `(default)` está ativo e que as Security Rules estão sendo aplicadas, sem abrir permissões para o teste. O código usado nessa validação foi removido depois.

Validações registradas na KAN-17: projeto Firebase ativo; banco `(default)` do tipo `FIRESTORE_NATIVE`; `firebase.json`, `firestore.rules` e `firestore.indexes.json` válidos; camada base no Flutter; `flutter analyze`; `flutter test`; `git diff --check`.

### A.3 - Estrutura local da integração

```text
.firebaserc
firebase.json
firestore.rules            # deny-all até a KAN-22
firestore.indexes.json     # vazio
docs/firestore-schema.md
lib/data/firestore/
├── firestore_collections.dart   # nomes das 5 coleções
├── firestore_service.dart       # acesso à instância, injetável
└── user_profile_repository.dart # KAN-32
```

### A.4 - Regras atuais (sem alteração)

```text
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

A KAN-17 não deve alterar essa política para `true` apenas para facilitar desenvolvimento ou testes. As permissões reais serão definidas na KAN-22.
