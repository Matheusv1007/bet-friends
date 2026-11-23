import 'dart:async';
import '../models/challenge_model.dart';

/// Une as duas consultas do resumo, cancelando ambas quando a tela sai.
Stream<List<ChallengeModel>> combinarDesafios(
  Stream<List<ChallengeModel>> ativos,
  Stream<List<ChallengeModel>> terminais,
) {
  final resultados = <List<ChallengeModel>?>[null, null];
  final assinaturas = <StreamSubscription<List<ChallengeModel>>>[];
  late final StreamController<List<ChallengeModel>> controller;
  controller = StreamController<List<ChallengeModel>>(
    onListen: () {
      final streams = [ativos, terminais];
      for (var i = 0; i < streams.length; i++) {
        final indice = i;
        assinaturas.add(streams[i].listen((desafios) {
          resultados[indice] = desafios;
          if (resultados.any((r) => r == null)) return;
          // Na transição entre consultas, a versão terminal prevalece.
          final porId = {
            for (final lista in resultados)
              for (final desafio in lista!) desafio.id: desafio,
          };
          controller.add(porId.values.toList());
        }, onError: controller.addError));
      }
    },
    onCancel: () async {
      await Future.wait(assinaturas.map((s) => s.cancel()));
    },
  );
  return controller.stream;
}
