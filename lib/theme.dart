import 'package:flutter/material.dart';

/// Um tema visual do MyMooscles: cores, cantos, bordas, sombra e fontes.
class MooTheme {
  final String key;
  final String label;
  final String description;
  final Brightness brightness;
  final Color bg; // fundo da tela
  final Color surf; // cartões
  final Color surf2; // campos, pílulas, áreas internas
  final Color line; // bordas
  final Color text;
  final Color muted;
  final Color acc; // destaque
  final Color onAcc; // texto sobre o destaque
  final Color good; // "subir carga"
  final Color shadow; // sombra "carimbada" (temas Moo)
  final Color navBg;
  final Color tint; // caixa de sugestão
  final double radius;
  final double radiusSmall;
  final double borderWidth;
  final double shadowOffset;
  final String bodyFont;
  final String headFont;
  final bool cowSpots;

  const MooTheme({
    required this.key,
    required this.label,
    required this.description,
    required this.brightness,
    required this.bg,
    required this.surf,
    required this.surf2,
    required this.line,
    required this.text,
    required this.muted,
    required this.acc,
    required this.onAcc,
    required this.good,
    required this.shadow,
    required this.navBg,
    required this.tint,
    required this.radius,
    required this.radiusSmall,
    required this.borderWidth,
    required this.shadowOffset,
    required this.bodyFont,
    required this.headFont,
    required this.cowSpots,
  });

  bool get isDark => brightness == Brightness.dark;

  /// Fundo e texto do cronômetro de descanso.
  Color get timerBg => key == 'noturno' ? acc : text;
  Color get timerFg => key == 'noturno' ? onAcc : bg;

  Border? get border => borderWidth > 0 ? Border.all(color: line, width: borderWidth) : null;

  List<BoxShadow>? shadowFor([double? offset]) {
    final o = offset ?? shadowOffset;
    if (o <= 0) return null;
    return [BoxShadow(color: shadow, offset: Offset(o, o))];
  }

  BoxDecoration card({Color? color}) => BoxDecoration(
        color: color ?? surf,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadowFor(),
      );

  TextStyle head(double size, {FontWeight weight = FontWeight.w700, Color? color}) => TextStyle(
        fontFamily: headFont,
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        height: 1.15,
      );

  TextStyle body(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        height: height,
      );

  TextStyle kicker() => body(12, weight: FontWeight.w700, color: muted).copyWith(letterSpacing: 0.8);

  InputDecoration input(String label, {String? suffix, String? hint, bool dense = false}) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: c, width: w),
        );
    final bw = borderWidth >= 2 ? 2.0 : 1.0;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      isDense: dense,
      filled: true,
      fillColor: surf2,
      labelStyle: body(14, color: muted),
      floatingLabelStyle: body(14, weight: FontWeight.w600, color: acc),
      hintStyle: body(14, color: muted),
      suffixStyle: body(14, color: muted),
      border: b(line, bw),
      enabledBorder: b(borderWidth >= 2 ? line : (isDark ? const Color(0xFF3A3F48) : line), bw),
      focusedBorder: b(acc, 2),
    );
  }

  ThemeData toThemeData() {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: acc,
      onPrimary: onAcc,
      secondary: acc,
      onSecondary: onAcc,
      error: const Color(0xFFD32F2F),
      onError: Colors.white,
      surface: surf,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerLowest: surf,
      surfaceContainerLow: surf,
      surfaceContainer: surf,
      surfaceContainerHigh: surf,
      surfaceContainerHighest: surf2,
      outline: line,
      outlineVariant: isDark ? const Color(0xFF3A3F48) : const Color(0xFFE1E5EC),
      primaryContainer: surf2,
      onPrimaryContainer: text,
      secondaryContainer: surf2,
      onSecondaryContainer: text,
      tertiaryContainer: surf2,
      onTertiaryContainer: text,
      errorContainer: isDark ? const Color(0xFF5C1D1D) : const Color(0xFFFBE3E3),
      onErrorContainer: isDark ? const Color(0xFFFFDAD6) : const Color(0xFF5C1D1D),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: isDark ? const Color(0xFF2E323A) : const Color(0xFFE1E5EC),
      fontFamily: bodyFont,
    );
  }
}

const mooThemes = <MooTheme>[
  MooTheme(
    key: 'moo',
    label: 'Moo',
    description: 'Preto e branco com rosa, bordas marcadas',
    brightness: Brightness.light,
    bg: Color(0xFFFFFFFF),
    surf: Color(0xFFFFFFFF),
    surf2: Color(0xFFF3F3F3),
    line: Color(0xFF141414),
    text: Color(0xFF141414),
    muted: Color(0xFF545454),
    acc: Color(0xFFC2185B),
    onAcc: Color(0xFFFFFFFF),
    good: Color(0xFF1B7A3E),
    shadow: Color(0xFF141414),
    navBg: Color(0xFFFFFFFF),
    tint: Color(0xFFF3F3F3),
    radius: 20,
    radiusSmall: 12,
    borderWidth: 2,
    shadowOffset: 4,
    bodyFont: 'Rubik',
    headFont: 'Rubik',
    cowSpots: true,
  ),
  MooTheme(
    key: 'moo_noturno',
    label: 'Moo Noturno',
    description: 'O Moo no escuro, com sombra rosa',
    brightness: Brightness.dark,
    bg: Color(0xFF121212),
    surf: Color(0xFF1C1C1C),
    surf2: Color(0xFF2A2A2A),
    line: Color(0xFFEDEDED),
    text: Color(0xFFF5F5F5),
    muted: Color(0xFFB8B8B8),
    acc: Color(0xFFFF6FA3),
    onAcc: Color(0xFF1A0A10),
    good: Color(0xFF7DDB9A),
    shadow: Color(0xFFFF6FA3),
    navBg: Color(0xFF161616),
    tint: Color(0xFF2A2A2A),
    radius: 20,
    radiusSmall: 12,
    borderWidth: 2,
    shadowOffset: 4,
    bodyFont: 'Rubik',
    headFont: 'Rubik',
    cowSpots: true,
  ),
  MooTheme(
    key: 'noturno',
    label: 'Noturno',
    description: 'Escuro com verde-limão, cara de academia',
    brightness: Brightness.dark,
    bg: Color(0xFF0E0F12),
    surf: Color(0xFF191B20),
    surf2: Color(0xFF24272E),
    line: Color(0xFF2E323A),
    text: Color(0xFFF2F3F5),
    muted: Color(0xFFA3A9B4),
    acc: Color(0xFFC8F25A),
    onAcc: Color(0xFF10120C),
    good: Color(0xFFC8F25A),
    shadow: Color(0x00000000),
    navBg: Color(0xFF121317),
    tint: Color(0xFF20240F),
    radius: 18,
    radiusSmall: 12,
    borderWidth: 0,
    shadowOffset: 0,
    bodyFont: 'Inter',
    headFont: 'SpaceGrotesk',
    cowSpots: false,
  ),
  MooTheme(
    key: 'claro',
    label: 'Claro',
    description: 'Branco e azul, limpo e arejado',
    brightness: Brightness.light,
    bg: Color(0xFFF2F4F7),
    surf: Color(0xFFFFFFFF),
    surf2: Color(0xFFEEF1F6),
    line: Color(0xFFE1E5EC),
    text: Color(0xFF11151C),
    muted: Color(0xFF566070),
    acc: Color(0xFF2F54EB),
    onAcc: Color(0xFFFFFFFF),
    good: Color(0xFF127A55),
    shadow: Color(0x00000000),
    navBg: Color(0xFFFFFFFF),
    tint: Color(0xFFEEF1F6),
    radius: 22,
    radiusSmall: 14,
    borderWidth: 1,
    shadowOffset: 0,
    bodyFont: 'PlusJakartaSans',
    headFont: 'PlusJakartaSans',
    cowSpots: false,
  ),
];

MooTheme themeFor(String key) => mooThemes.firstWhere((t) => t.key == key, orElse: () => mooThemes.first);

/// Disponibiliza o tema atual para qualquer tela: MooThemeScope.of(context).
class MooThemeScope extends InheritedWidget {
  final MooTheme theme;
  const MooThemeScope({super.key, required this.theme, required super.child});

  static MooTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MooThemeScope>()?.theme ?? mooThemes.first;

  @override
  bool updateShouldNotify(MooThemeScope oldWidget) => oldWidget.theme.key != theme.key;
}
