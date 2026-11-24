import 'package:flutter/material.dart';

/// Variantes do logo, aparadas a partir de `docs/marca/BetFriends_Kit_Logo/`.
enum VarianteDoLogo {
  /// Símbolo e nome lado a lado (kit 01), para fundo escuro.
  horizontal('assets/brand/logo_horizontal.png', 2200 / 256, 32),

  /// Mesma composição com o nome escuro (kit 07), para fundo claro.
  horizontalFundoClaro('assets/brand/logo_horizontal_claro.png', 2200 / 256, 32),

  /// Símbolo sobre o nome (kit 02).
  vertical('assets/brand/logo_vertical.png', 1180 / 846, 120),

  /// Só o "BF" bicolor (kit 03).
  monograma('assets/brand/logo_monograma.png', 789 / 331, 40);

  const VarianteDoLogo(this.asset, this.proporcao, this.alturaPadrao);

  final String asset;

  /// Largura / altura do arquivo aparado.
  final double proporcao;

  final double alturaPadrao;
}

/// Logo do BetFriends. Informe [altura] ou [largura]; a outra medida sai da
/// proporção real do arquivo. Sem nenhuma, usa a altura padrão da variante.
class LogoBetFriends extends StatelessWidget {
  const LogoBetFriends({
    super.key,
    this.variante = VarianteDoLogo.horizontal,
    this.altura,
    this.largura,
    this.semanticLabel = 'BetFriends',
  }) : assert(altura == null || largura == null, 'Informe altura ou largura, não ambas.');

  final VarianteDoLogo variante;
  final double? altura;
  final double? largura;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final h = altura ?? (largura != null ? largura! / variante.proporcao : variante.alturaPadrao);
    return Image.asset(
      variante.asset,
      width: h * variante.proporcao,
      height: h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
    );
  }
}
