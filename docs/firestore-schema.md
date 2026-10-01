# Firestore - Estrutura Inicial do BetFriends

## 1 - Objetivo

Este documento define a estrutura inicial de persistência do BetFriends criada na KAN-17.

A KAN-17 prepara o Firestore para os módulos futuros, mas não implementa as regras de negócio dessas funcionalidades.

## 2 - Banco

Database ID:

`(default)`

Location:

`southamerica-east1`

## 3 - Coleções

### 3.1 - users

Caminho:

`users/{uid}`

O identificador do documento deverá corresponder ao UID fornecido pelo Firebase Authentication.

Estrutura prevista:

```text
displayName
username
usernameNormalized
email
createdAt
updatedAt
```

A implementação funcional do perfil será realizada em tasks posteriores.

### 3.2 - friendships

Caminho:

`friendships/{friendshipId}`

Estrutura prevista:

```text
userAId
userBId
status
createdAt
updatedAt
```

As regras e operações de amizade não fazem parte da KAN-17.

### 3.3 - matches

Caminho:

`matches/{matchId}`

Estrutura prevista:

```text
externalId
homeTeam
awayTeam
utcDate
status
result
createdAt
updatedAt
```

O modelo definitivo de Match será refinado nas tasks específicas do módulo de partidas.

### 3.4 - challenges

Caminho:

`challenges/{challengeId}`

Estrutura prevista:

```text
challengerId
challengedId
matchId
amount
status
createdAt
updatedAt
```

A persistência e as regras de negócio de Challenge serão implementadas posteriormente.

### 3.5 - betCoinTransactions

Caminho:

`betCoinTransactions/{transactionId}`

Estrutura prevista:

```text
userId
type
amount
challengeId
createdAt
metadata
```

As operações financeiras e as regras do ledger não fazem parte da KAN-17.

## 4 - Datas e horários

Datas sensíveis ao domínio devem ser persistidas utilizando `Timestamp` do Firestore.

Quando uma data tiver origem no cliente, ela deve ser convertida para UTC antes da persistência.

Exemplo:

```dart
Timestamp.fromDate(date.toUtc())
```

Quando a data representar o momento em que a gravação ocorreu no servidor, deve-se preferir:

```dart
FieldValue.serverTimestamp()
```

Datas não devem ser persistidas como strings formatadas, por exemplo:

```text
01/10/2026 15:30
```

A aplicação poderá converter os valores UTC para o fuso horário local somente na camada de apresentação.

## 5 - Segurança

As regras atuais do Firestore permanecem restritivas.

Configuração atual:

```text
allow read, write: if false;
```

A definição das regras funcionais de acesso ao banco será realizada na KAN-22.

A KAN-17 não deve liberar acesso público ou irrestrito ao Firestore.

## 6 - Validação técnica

Durante a KAN-17 foi realizada uma consulta técnica do aplicativo Flutter ao Cloud Firestore.

A consulta alcançou o banco real e retornou `PERMISSION_DENIED`, conforme esperado pelas regras atuais.

Isso confirmou o seguinte fluxo:

```text
Flutter
   ↓
Firebase
   ↓
Cloud Firestore
   ↓
Security Rules
   ↓
Acesso negado conforme configuração atual
```

O código utilizado exclusivamente para essa validação foi removido após o teste.

A validação demonstrou que:

- o aplicativo Flutter está conectado ao projeto Firebase correto;
- o Cloud Firestore está acessível pelo aplicativo;
- o banco `(default)` está ativo;
- as Security Rules estão sendo aplicadas;
- nenhuma permissão pública foi aberta apenas para realizar o teste.

## 7 - Estrutura local da integração

A configuração inicial da KAN-17 adiciona os seguintes arquivos relacionados ao Firestore:

```text
.firebaserc
firebase.json
firestore.rules
firestore.indexes.json

docs/
└── firestore-schema.md

lib/
└── data/
    └── firestore/
        ├── firestore_collections.dart
        └── firestore_service.dart
```

### 7.1 - firestore_collections.dart

O arquivo centraliza os nomes das coleções utilizadas pelo projeto.

Coleções definidas:

```text
users
friendships
matches
challenges
betCoinTransactions
```

Essa centralização evita espalhar strings com nomes de coleções em diferentes partes do código.

### 7.2 - firestore_service.dart

O `FirestoreService` fornece uma camada base de acesso ao `FirebaseFirestore`.

A estrutura inicial permite utilizar a instância padrão do Firestore e também possibilita injetar outra instância futuramente, facilitando testes e evolução da arquitetura.

A KAN-17 não implementa operações específicas de domínio dentro desse serviço.

## 8 - Responsabilidades futuras por coleção

A definição estrutural das coleções na KAN-17 não significa que seus respectivos módulos já estejam implementados.

### 8.1 - users

Será utilizada posteriormente para funcionalidades como:

- perfil vinculado ao UID;
- username;
- dados básicos do usuário;
- informações necessárias para outros módulos.

Tasks relacionadas incluem principalmente KAN-31 e KAN-32.

### 8.2 - friendships

Será utilizada pelo módulo de amizades.

As regras de solicitação, aceitação, rejeição e prevenção de duplicidade serão implementadas nas tasks específicas desse módulo.

### 8.3 - matches

Será utilizada para persistir partidas normalizadas pelo backend.

O modelo definitivo, os status, os resultados e a sincronização serão implementados nas tasks específicas do módulo de partidas.

### 8.4 - challenges

Será utilizada para persistir os desafios criados entre usuários.

O modelo, estados e operações do desafio serão implementados posteriormente nas tasks específicas de Challenges.

### 8.5 - betCoinTransactions

Será utilizada como base para o registro auditável das movimentações de BetCoins.

A lógica financeira, reservas, premiações, perdas, reembolsos e demais operações serão implementadas nas tasks específicas do módulo financeiro.

## 9 - Regras de modelagem

A estrutura inicial deve seguir algumas regras gerais.

### 9.1 - Identidade de usuário

O Firebase Authentication UID será a identidade técnica estável do usuário.

O documento principal de usuário deverá utilizar:

```text
users/{uid}
```

O username não deve substituir o UID como chave técnica principal.

### 9.2 - Referências entre entidades

Relacionamentos entre documentos devem utilizar identificadores estáveis.

Exemplos:

```text
challengerId
challengedId
userAId
userBId
matchId
challengeId
```

### 9.3 - Datas

Datas persistidas devem utilizar tipos próprios do Firestore, preferencialmente `Timestamp`.

Para eventos gerados pelo servidor, deve-se preferir `FieldValue.serverTimestamp()` quando aplicável.

### 9.4 - Regras de negócio

Regras de negócio não devem ser implementadas dentro da definição estrutural da KAN-17.

A KAN-17 fornece apenas a infraestrutura necessária para que essas regras sejam implementadas nas tasks correspondentes.

## 10 - Segurança

O arquivo `firestore.rules` permanece com acesso bloqueado por padrão.

Configuração atual:

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

Essa configuração impede leitura e escrita indiscriminadas.

As permissões reais por coleção e por usuário serão definidas posteriormente na KAN-22.

A KAN-17 não deve alterar essa política para `true` apenas para facilitar desenvolvimento ou testes.

## 11 - Índices

O arquivo:

`firestore.indexes.json`

foi adicionado ao projeto para permitir o versionamento dos índices do Firestore.

No momento da KAN-17 não existem índices compostos específicos necessários.

A configuração inicial permanece:

```json
{
  "indexes": [],
  "fieldOverrides": []
}
```

Índices adicionais deverão ser adicionados somente quando consultas reais do projeto exigirem.

## 12 - Configuração Firebase

O projeto local está associado ao Firebase:

`betfriends-unirv-2026`

O alias padrão configurado é:

`default`

O banco utilizado é:

`(default)`

A localização configurada é:

`southamerica-east1`

O Firestore utiliza o modo:

`FIRESTORE_NATIVE`

Edição:

`STANDARD`

## 13 - Validações realizadas

Durante a implementação da KAN-17 foram realizadas as seguintes validações:

- confirmação do projeto Firebase ativo;
- confirmação da existência do banco `(default)`;
- confirmação do tipo `FIRESTORE_NATIVE`;
- inicialização local da configuração do Firestore;
- validação do `firebase.json`;
- validação de `firestore.rules`;
- validação de `firestore.indexes.json`;
- criação da camada base no Flutter;
- teste real Flutter para Firestore;
- confirmação de aplicação das Security Rules;
- execução de `flutter analyze`;
- execução de `flutter test`;
- execução de `git diff --check`.

O teste de conexão retornou:

`PERMISSION_DENIED`

Esse resultado era esperado porque as regras atuais bloqueiam todas as leituras e escritas.

Portanto, o retorno confirmou que a requisição alcançou o Firestore e foi processada pelas regras de segurança.

## 14 - Escopo da KAN-17

A KAN-17 configura a infraestrutura inicial de persistência do projeto.

Fazem parte desta task:

- habilitação e validação do Cloud Firestore;
- associação do projeto local ao Firebase;
- configuração do banco `(default)`;
- configuração de `firebase.json`;
- criação e versionamento de `.firebaserc`;
- versionamento de `firestore.rules`;
- versionamento de `firestore.indexes.json`;
- definição das coleções principais;
- documentação da estrutura inicial do banco;
- criação da camada base de acesso ao Firestore no Flutter;
- definição do padrão de datas UTC;
- validação técnica Flutter para Firestore.

## 15 - Fora do escopo da KAN-17

Não fazem parte desta task:

- cadastro funcional de usuários;
- validação de username único;
- persistência funcional de perfil;
- regras completas de segurança;
- implementação funcional de amizades;
- sincronização definitiva de partidas;
- implementação do modelo completo de Match;
- criação funcional de desafios;
- persistência completa de Challenge;
- operações financeiras de BetCoins;
- ledger financeiro;
- liquidação de desafios;
- histórico;
- Callable Functions;
- backend funcional completo.

Essas responsabilidades pertencem às tasks específicas do backlog.

## 16 - Próximas dependências

A conclusão da KAN-17 fornece a base necessária para diversas tasks posteriores.

Entre elas:

- KAN-22 - regras iniciais de segurança do Firestore;
- KAN-25 - criação real de conta;
- KAN-31 - validação de username único;
- KAN-32 - perfil vinculado ao UID;
- KAN-40 - prevenção de solicitações duplicadas;
- KAN-45 - FootballService;
- KAN-46 - modelo interno Match;
- KAN-49 - sincronização de partidas;
- KAN-62 - modelo e persistência de Challenge;
- KAN-72 - inicialização de carteira;
- KAN-73 - cálculo dos saldos;
- KAN-79 - transações auditáveis de BetCoins.

A existência do Firestore não significa que essas tasks estejam automaticamente concluídas.

A KAN-17 apenas remove a dependência estrutural relacionada à disponibilidade e configuração inicial do banco.

## 17 - Resultado da KAN-17

Ao final da KAN-17, o projeto passa a possuir uma base de persistência versionada e preparada para evolução.

O fluxo estrutural passa a ser:

```text
Flutter
   ↓
Firebase Core
   ↓
Cloud Firestore
   ↓
Coleções do domínio
   ↓
Regras específicas e funcionalidades futuras
```

A implementação mantém separação entre infraestrutura, segurança e regras de negócio, permitindo que os módulos seguintes sejam desenvolvidos sem concentrar responsabilidades indevidas dentro da KAN-17.
