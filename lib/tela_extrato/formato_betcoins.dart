/// Número inteiro com ponto como separador de milhar ("1.000").
String formatarBetCoins(int valor) {
  final digitos = valor.abs().toString();
  final grupos = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) grupos.write('.');
    grupos.write(digitos[i]);
  }
  return '${valor < 0 ? '−' : ''}$grupos';
}
