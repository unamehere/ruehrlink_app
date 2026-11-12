import 'package:flutter/services.dart';

/// Zeiteingabe nur mit Ziffern, der Doppelpunkt kommt automatisch –
/// von rechts gelesen wie an einer Mikrowelle: „130“ → `1:30`, „13000“ → `1:30:00`.
class DurationDigitsFormatter extends TextInputFormatter {
  static const maxDigits = 6;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final text = formatDurationDigits(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Ziffernfolge als `ss`, `m:ss` oder `h:mm:ss`.
String formatDurationDigits(String d) {
  final n = d.length;
  if (n <= 2) return d;
  if (n <= 4) return '${d.substring(0, n - 2)}:${d.substring(n - 2)}';
  return '${d.substring(0, n - 4)}:${d.substring(n - 4, n - 2)}:'
      '${d.substring(n - 2)}';
}

/// Sekunden aus einer Eingabe wie `1:30` oder `1:05:00`; `null` bei leer oder
/// ungültig (z. B. `1:75`). Nur Sekunden (`90`) sind erlaubt.
int? parseDurationText(String text) {
  final d = text.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;
  final n = d.length;
  final s = int.parse(d.substring(n > 2 ? n - 2 : 0));
  final m = n > 2 ? int.parse(d.substring(n > 4 ? n - 4 : 0, n - 2)) : 0;
  final h = n > 4 ? int.parse(d.substring(0, n - 4)) : 0;
  if (n > 2 && s >= 60) return null;
  if (n > 4 && m >= 60) return null;
  return h * 3600 + m * 60 + s;
}
