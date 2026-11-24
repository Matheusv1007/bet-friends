import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cores_app.dart';
import 'raios_app.dart';
import 'texto_app.dart';

/// Tema escuro único do app (Material 3), montado só com os tokens.
abstract final class TemaApp {
  /// Barras do sistema: ícones claros, barra de status transparente e barra
  /// de navegação na cor de fundo.
  static const barrasDoSistema = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: CoresApp.fundo,
    systemNavigationBarDividerColor: CoresApp.fundo,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  static const esquemaDeCores = ColorScheme(
    brightness: Brightness.dark,
    primary: CoresApp.primario,
    onPrimary: CoresApp.sobrePrimario,
    primaryContainer: CoresApp.primarioSuave,
    onPrimaryContainer: CoresApp.texto,
    secondary: CoresApp.primario,
    onSecondary: CoresApp.sobrePrimario,
    secondaryContainer: CoresApp.primarioSuave,
    onSecondaryContainer: CoresApp.texto,
    tertiary: CoresApp.atencao,
    onTertiary: CoresApp.fundo,
    error: CoresApp.destrutivo,
    onError: CoresApp.fundo,
    surface: CoresApp.fundo,
    onSurface: CoresApp.texto,
    onSurfaceVariant: CoresApp.textoSuave,
    surfaceDim: CoresApp.fundo,
    surfaceBright: CoresApp.superficie2,
    surfaceContainerLowest: CoresApp.fundo,
    surfaceContainerLow: CoresApp.superficie1,
    surfaceContainer: CoresApp.superficie1,
    surfaceContainerHigh: CoresApp.superficie2,
    surfaceContainerHighest: CoresApp.superficie2,
    outline: CoresApp.contorno,
    outlineVariant: CoresApp.filete,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: CoresApp.texto,
    onInverseSurface: CoresApp.fundo,
    inversePrimary: CoresApp.primario,
    surfaceTint: Colors.transparent,
  );

  static final ThemeData escuro = _criar();

  static ThemeData _criar() {
    const formaBotao = RoundedRectangleBorder(borderRadius: RaiosApp.bordaBotao);
    const tamanhoBotao = Size(64, 48);
    const preenchimentoBotao = EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    const textoBotao = TextoApp.corpoForte;

    OutlineInputBorder borda(Color cor, [double largura = 1]) => OutlineInputBorder(
          borderRadius: RaiosApp.bordaBotao,
          borderSide: BorderSide(color: cor, width: largura),
        );

    final botaoPrimario = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? CoresApp.superficie2 : CoresApp.primario,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? CoresApp.textoSuave : CoresApp.sobrePrimario,
      ),
      overlayColor: WidgetStatePropertyAll(CoresApp.sobrePrimario.withValues(alpha: 0.12)),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      minimumSize: const WidgetStatePropertyAll(tamanhoBotao),
      padding: const WidgetStatePropertyAll(preenchimentoBotao),
      shape: const WidgetStatePropertyAll(formaBotao),
      textStyle: WidgetStatePropertyAll(textoBotao),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: esquemaDeCores,
      fontFamily: TextoApp.familia,
      textTheme: TextoApp.textTheme,
      primaryTextTheme: TextoApp.textTheme,
      scaffoldBackgroundColor: CoresApp.fundo,
      canvasColor: CoresApp.fundo,
      dividerColor: CoresApp.filete,
      iconTheme: const IconThemeData(color: CoresApp.texto, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: CoresApp.fundo,
        foregroundColor: CoresApp.texto,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextoApp.tituloDeBarra.copyWith(color: CoresApp.texto),
        iconTheme: const IconThemeData(color: CoresApp.texto),
        actionsIconTheme: const IconThemeData(color: CoresApp.texto),
        systemOverlayStyle: barrasDoSistema,
      ),
      filledButtonTheme: FilledButtonThemeData(style: botaoPrimario),
      elevatedButtonTheme: ElevatedButtonThemeData(style: botaoPrimario),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CoresApp.texto,
          disabledForegroundColor: CoresApp.textoSuave,
          side: const BorderSide(color: CoresApp.contorno),
          minimumSize: tamanhoBotao,
          padding: preenchimentoBotao,
          shape: formaBotao,
          textStyle: textoBotao,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CoresApp.primario,
          disabledForegroundColor: CoresApp.textoSuave,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: formaBotao,
          textStyle: textoBotao,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: CoresApp.texto,
          minimumSize: const Size(48, 48),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: CoresApp.primario,
        foregroundColor: CoresApp.sobrePrimario,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: RaiosApp.bordaCartao),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CoresApp.superficie2,
        hintStyle: TextoApp.corpo.copyWith(color: CoresApp.textoSuave),
        labelStyle: TextoApp.corpo.copyWith(color: CoresApp.textoSuave),
        floatingLabelStyle: TextoApp.secundario.copyWith(color: CoresApp.primario),
        helperStyle: TextoApp.secundario,
        errorStyle: TextoApp.secundario.copyWith(color: CoresApp.destrutivo),
        errorMaxLines: 3,
        prefixIconColor: CoresApp.textoSuave,
        suffixIconColor: CoresApp.textoSuave,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: borda(CoresApp.contorno),
        enabledBorder: borda(CoresApp.contorno),
        disabledBorder: borda(CoresApp.filete),
        focusedBorder: borda(CoresApp.primario, 1.5),
        errorBorder: borda(CoresApp.destrutivo),
        focusedErrorBorder: borda(CoresApp.destrutivo, 1.5),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? CoresApp.primarioSuave : CoresApp.superficie1,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.selected) ? CoresApp.primario : CoresApp.filete,
          ),
        ),
        labelStyle: TextoApp.corpo.copyWith(
          fontWeight: FontWeight.w500,
          color: CoresApp.texto,
        ),
        secondaryLabelStyle: TextoApp.corpo.copyWith(
          fontWeight: FontWeight.w500,
          color: CoresApp.texto,
        ),
        checkmarkColor: CoresApp.primario,
        iconTheme: const IconThemeData(color: CoresApp.textoSuave, size: 18),
        shape: const RoundedRectangleBorder(borderRadius: RaiosApp.bordaChip),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        selectedShadowColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CoresApp.superficie2,
        contentTextStyle: TextoApp.corpo.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: CoresApp.texto,
        ),
        actionTextColor: CoresApp.primario,
        closeIconColor: CoresApp.textoSuave,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: RaiosApp.bordaBotao,
          side: BorderSide(color: CoresApp.contorno),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CoresApp.superficie1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: RaiosApp.bordaCartao,
          side: BorderSide(color: CoresApp.filete),
        ),
        titleTextStyle: TextoApp.tituloDeBarra.copyWith(color: CoresApp.texto),
        contentTextStyle: TextoApp.corpo.copyWith(color: CoresApp.texto),
        iconColor: CoresApp.textoSuave,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CoresApp.superficie1,
        modalBackgroundColor: CoresApp.superficie1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: CoresApp.contorno,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(RaiosApp.cartao)),
        ),
      ),
      cardTheme: const CardThemeData(
        color: CoresApp.superficie1,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: RaiosApp.bordaCartao),
      ),
      dividerTheme: const DividerThemeData(color: CoresApp.filete, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CoresApp.primario,
        linearTrackColor: CoresApp.superficie2,
        circularTrackColor: Colors.transparent,
        refreshBackgroundColor: CoresApp.superficie1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: CoresApp.primario,
        selectionColor: CoresApp.primario.withValues(alpha: 0.35),
        selectionHandleColor: CoresApp.primario,
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(CoresApp.contorno),
        radius: Radius.circular(RaiosApp.chip),
        thickness: WidgetStatePropertyAll(4),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: CoresApp.textoSuave,
        textColor: CoresApp.texto,
        selectedColor: CoresApp.primario,
        titleTextStyle: TextoApp.corpo.copyWith(color: CoresApp.texto),
        subtitleTextStyle: TextoApp.secundario,
        leadingAndTrailingTextStyle: TextoApp.secundario,
        minTileHeight: 48,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const RoundedRectangleBorder(borderRadius: RaiosApp.bordaCartao),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: CoresApp.superficie2,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: RaiosApp.bordaBotao,
          side: BorderSide(color: CoresApp.contorno),
        ),
        textStyle: TextoApp.corpo.copyWith(color: CoresApp.texto),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: CoresApp.superficie2,
          borderRadius: RaiosApp.bordaChip,
        ),
        textStyle: TextoApp.minimo.copyWith(color: CoresApp.texto),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: CoresApp.superficie1,
        surfaceTintColor: Colors.transparent,
        indicatorColor: CoresApp.primarioSuave,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextoApp.minimo.copyWith(
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? CoresApp.primario : CoresApp.textoSuave,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? CoresApp.primario : CoresApp.textoSuave,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: CoresApp.superficie1,
        selectedItemColor: CoresApp.primario,
        unselectedItemColor: CoresApp.textoSuave,
        selectedLabelStyle: TextoApp.minimo.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextoApp.minimo,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: CoresApp.texto,
        unselectedLabelColor: CoresApp.textoSuave,
        indicatorColor: CoresApp.primario,
        dividerColor: CoresApp.filete,
        labelStyle: TextoApp.corpoForte,
        unselectedLabelStyle: TextoApp.corpo,
      ),
      // Transição curta e discreta entre telas: esmaece e desliza pouco.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
      ),
    );
  }
}
