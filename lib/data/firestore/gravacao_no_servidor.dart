import 'package:cloud_firestore/cloud_firestore.dart';

/// Prazo para o código da transação terminar antes de ela ser abortada.
const prazoDaGravacao = Duration(seconds: 15);

/// Política de gravação do app no Firestore sem conexão (KAN-24; RN-OFF-002,
/// RNF-009).
///
/// Um `set`/`update`/`delete` comum, sem conexão, é aplicado no cache, entra
/// na fila local e é enviado sozinho quando a conexão volta: a tela veria a
/// alteração como feita, e ela seria gravada depois sem nova ação do usuário.
///
/// Por isso toda gravação do app no Firestore passa por aqui, numa transação:
/// ela só termina depois que o servidor confirma e, sem conexão, falha com
/// `unavailable` sem deixar nada na fila. Repetir a operação depende de uma
/// nova ação do usuário. Saldos, amizades e desafios não são gravados pelo
/// app (firestore.rules); passam pelas Callable Functions, que também exigem
/// o servidor (ver `FunctionsException.semConfirmacaoDoServidor`).
Future<T> gravarNoServidor<T>(
  FirebaseFirestore db,
  TransactionHandler<T> operacao,
) {
  return db.runTransaction(operacao, timeout: prazoDaGravacao);
}
