// Guarda da política de gravação offline (KAN-24, RNF-009): no app, o
// Firestore só é gravado por transações de gravarNoServidor. Um set/update/
// delete/add/batch direto seria aplicado no cache sem conexão e enviado mais
// tarde sem nova ação do usuário. Verificação textual: se acusar um falso
// positivo, mova o código para fora do arquivo que importa o Firestore.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _escritaDireta = RegExp(r'(?<!transaction)\.(set|update|delete|add)\(|\.batch\(\)');

void main() {
  final arquivosComFirestore = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => f.readAsStringSync().contains('package:cloud_firestore/'))
      .toList();

  test('há código do app usando o Firestore para verificar', () {
    expect(arquivosComFirestore, isNotEmpty);
  });

  test('nenhuma gravação direta no Firestore fora de transação', () {
    final violacoes = <String>[];
    for (final arquivo in arquivosComFirestore) {
      final linhas = arquivo.readAsLinesSync();
      for (var i = 0; i < linhas.length; i++) {
        final linha = linhas[i].trim();
        if (linha.startsWith('//')) continue;
        if (_escritaDireta.hasMatch(linha)) violacoes.add('${arquivo.path}:${i + 1}: $linha');
      }
    }
    expect(violacoes, isEmpty, reason: 'Use gravarNoServidor (lib/data/firestore/gravacao_no_servidor.dart)');
  });

  test('transações só são abertas por gravarNoServidor', () {
    final fora = arquivosComFirestore
        .where((f) => !f.path.endsWith('gravacao_no_servidor.dart'))
        .where((f) => f.readAsStringSync().contains('runTransaction('))
        .map((f) => f.path);
    expect(fora, isEmpty);
  });
}
