import 'package:flutter/material.dart';

/// Tela de Informações e Créditos do Aplicativo (KAN-54; RNF-011, RNF-012, D-015).
///
/// Apresenta as informações mínimas do produto e a atribuição legal obrigatória
/// ao provedor de dados de futebol ([RNF-011]):
/// "Dados fornecidos por football-data.org".
///
/// A atribuição e os dados são estáticos e locais, permanecendo disponíveis
/// independentemente do estado do provedor ou de conexão com a internet.
///
/// Conforme [RNF-012], os escudos são exibidos pela URL do provedor, sem cópia nem
/// armazenamento; o app não distribui imagens de terceiros.
class TelaInformacoesCreditos extends StatelessWidget {
  const TelaInformacoesCreditos({super.key});

  /// Texto de atribuição obrigatória exigido por RNF-011.
  static const String textoAtribuicaoProvedor =
      'Dados fornecidos por football-data.org';

  @override
  Widget build(BuildContext context) {
    const bgScaffold = Color(0xFF0B111D);
    const cardBg = Color(0xFF151E2E);
    const primaryGreen = Color(0xFF00D084);
    const textMuted = Color(0xFF8E9CAB);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        key: const Key('appbar_informacoes_creditos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Informações e Créditos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.85, -0.9),
            radius: 1.2,
            colors: [Color(0xFF0F2624), Color(0xFF0B111D), Color(0xFF0B111D)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Identificação do aplicativo (estilizada com ícones padrão Flutter, sem imagens externas)
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B2421),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryGreen, width: 2),
                      ),
                      child: const Icon(
                        Icons.sports_soccer,
                        color: primaryGreen,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'BetFriends',
                      key: Key('app_nome'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Versão 1.0.0 (MVP)',
                      key: Key('app_versao'),
                      style: TextStyle(
                        color: primaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Desafios e palpites esportivos entre amigos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // CARD DE ATRIBUIÇÃO OBRIGATÓRIA (RNF-011)
              Container(
                key: const Key('card_atribuicao_provedor'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: primaryGreen.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.verified_outlined,
                          color: primaryGreen,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Créditos de Dados',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Texto exato exigido pelo critério de aceitação (RNF-011)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Text(
                        textoAtribuicaoProvedor,
                        key: Key('texto_atribuicao_football_data'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'As informações de partidas de futebol, competições, resultados e '
                      'calendários exibidas no aplicativo são obtidas a partir dos serviços '
                      'da API football-data.org.',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Esta atribuição permanece disponível de forma permanente e independente '
                      'do estado de conexão ou disponibilidade do provedor externo.',
                      key: Key('nota_disponibilidade_atribuicao'),
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // CARD DE PROPRIEDADE INTELECTUAL E LICENCIAMENTO (RNF-012, D-015)
              Container(
                key: const Key('card_propriedade_intelectual'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.shield_outlined,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Licenciamento e Escudos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Os escudos dos clubes são marcas de seus respectivos titulares e '
                      'são exibidos a partir do provedor de dados (football-data.org), '
                      'sem cópia nem armazenamento pelo app. O BetFriends é um projeto '
                      'acadêmico, sem fins comerciais.',
                      key: Key('texto_licenciamento_escudos'),
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Quando o provedor não informa o escudo ou ele não pode ser '
                      'carregado, o time é identificado pelo nome e por um ícone de '
                      'escudo padronizado.',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // CARD DE ESCOPO DO MVP (D-015)
              Container(
                key: const Key('card_escopo_mvp'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF38BDF8),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Finalidade do Aplicativo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'O BetFriends foi desenvolvido exclusivamente para fins de entretenimento '
                      'e interação social entre amigos. O saldo de BetCoins é meramente virtual '
                      'e não possui valor monetário, não havendo compras com dinheiro real nem apostas financeiras.',
                      key: Key('texto_finalidade_app'),
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
