import 'dart:ui' as ui;

import 'package:betfriends/widgets/logo_bet_friends.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('os assets do logo estão declarados em 1x, 2x e 3x com a proporção do widget',
      (tester) async {
    final manifesto = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final v in VarianteDoLogo.values) {
      expect(manifesto.listAssets(), contains(v.asset), reason: v.name);
      final densidades = manifesto
          .getAssetVariants(v.asset)!
          .map((a) => a.targetDevicePixelRatio ?? 1.0)
          .toSet();
      expect(densidades, containsAll(<double>[1, 2, 3]), reason: v.name);

      final bytes = await rootBundle.load(v.asset);
      final tamanho = (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        final imagem = (await codec.getNextFrame()).image;
        return Size(imagem.width.toDouble(), imagem.height.toDouble());
      }))!;
      expect(tamanho.aspectRatio, closeTo(v.proporcao, v.proporcao * 0.02), reason: v.name);
    }
  });

  for (final v in VarianteDoLogo.values) {
    testWidgets('LogoBetFriends ${v.name} respeita a proporção e tem rótulo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LogoBetFriends(key: const Key('por_altura'), variante: v, altura: 40),
            LogoBetFriends(key: const Key('por_largura'), variante: v, largura: 200),
            LogoBetFriends(key: const Key('padrao'), variante: v),
          ]),
        ),
      ));

      final porAltura = tester.getSize(find.byKey(const Key('por_altura')));
      expect(porAltura.height, 40);
      expect(porAltura.width, closeTo(40 * v.proporcao, 0.01));
      final porLargura = tester.getSize(find.byKey(const Key('por_largura')));
      expect(porLargura.width, closeTo(200, 0.01));
      expect(porLargura.height, closeTo(200 / v.proporcao, 0.01));
      expect(tester.getSize(find.byKey(const Key('padrao'))).height, v.alturaPadrao);
      expect(find.bySemanticsLabel('BetFriends'), findsNWidgets(3));
    });
  }
}
