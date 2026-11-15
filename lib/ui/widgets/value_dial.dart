import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../theme.dart';

/// Großer Regler für einen Maschinenwert: Beschriftung, großer Wert, − und +.
/// Mit [editor] lässt sich der Wert antippen und direkt eintippen; „Fertig“
/// auf der Tastatur übernimmt ihn. Ungültige Eingaben werden rot markiert und
/// nicht übernommen – nichts wird stillschweigend geändert.
///
/// Rein darstellend – welche Werte erlaubt sind und in welchen Schritten,
/// entscheidet der Aufrufer (aus den `caps` des Geräts). Ein `null`-Callback
/// sperrt die jeweilige Taste (Grenze erreicht).
class ValueDial extends StatefulWidget {
  const ValueDial({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.icon,
    this.editor,
    this.action,
  });

  final String label;

  /// Fertig formatierter Wert, z. B. „120 °C“ oder „4:30“.
  final String value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final IconData? icon;
  final ValueEditor? editor;

  /// Kleiner Zusatzknopf rechts in der Kopfzeile (über dem Plus), z. B. Temperatur-Vorschläge.
  final Widget? action;

  @override
  State<ValueDial> createState() => _ValueDialState();
}

/// Direkteingabe für einen [ValueDial].
class ValueEditor {
  const ValueEditor({
    required this.text,
    required this.validate,
    required this.onSubmit,
    this.formatters = const [],
    this.suffix,
    this.hint,
    this.maxLength,
    this.onValidityChanged,
  });

  /// Ausgangstext beim Antippen (z. B. „120“ oder „1:30“).
  final String text;

  /// Fehlermeldung für ungültigen Text, sonst `null`.
  final String? Function(String text) validate;

  /// Wird nur mit gültigem Text aufgerufen.
  final ValueChanged<String> onSubmit;
  final List<TextInputFormatter> formatters;
  final String? suffix;

  /// Platzhalter bei leerem Feld (z. B. „Aus“).
  final String? hint;
  final int? maxLength;

  /// Meldet bei jeder Eingabe, ob der Text gerade gültig ist (z. B. um
  /// „Senden“ zu sperren). Beim Verlassen der Eingabe wieder `true`.
  final ValueChanged<bool>? onValidityChanged;
}

class _ValueDialState extends State<ValueDial> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // Fokus verloren (z. B. woanders getippt): gültige Eingabe übernehmen,
      // ungültige rot stehen lassen.
      if (!_focus.hasFocus && _editing) _submit(keepFocus: false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    final editor = widget.editor!;
    _controller.value = TextEditingValue(
      text: editor.text,
      selection: TextSelection(baseOffset: 0, extentOffset: editor.text.length),
    );
    setState(() {
      _editing = true;
      _error = null;
    });
    _focus.requestFocus();
  }

  void _submit({bool keepFocus = true}) {
    final editor = widget.editor;
    if (editor == null || !mounted) return;
    final error = editor.validate(_controller.text);
    if (error != null) {
      editor.onValidityChanged?.call(false);
      setState(() => _error = error);
      if (keepFocus) _focus.requestFocus();
      return;
    }
    editor.onSubmit(_controller.text);
    editor.onValidityChanged?.call(true);
    setState(() {
      _editing = false;
      _error = null;
    });
    _focus.unfocus();
  }

  /// − und + beenden eine laufende Eingabe ohne Übernahme.
  VoidCallback? _wrap(VoidCallback? action) => action == null
      ? null
      : () {
          if (_editing) {
            widget.editor?.onValidityChanged?.call(true);
            setState(() {
              _editing = false;
              _error = null;
            });
            _focus.unfocus();
          }
          action();
        };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final editor = widget.editor;
    final big = theme.textTheme.displaySmall;

    final Widget center = _editing && editor != null
        ? TextField(
            controller: _controller,
            focusNode: _focus,
            textAlign: TextAlign.center,
            style: big,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              ...editor.formatters,
              if (editor.maxLength != null)
                LengthLimitingTextInputFormatter(editor.maxLength),
            ],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: Tokens.s),
              hintText: editor.hint,
              suffixText: editor.suffix,
              suffixStyle: theme.textTheme.titleLarge,
              // Roter Rahmen ohne Text; die Meldung steht unter der Zeile.
              error: _error == null ? null : const SizedBox.shrink(),
            ),
            onSubmitted: (_) => _submit(),
            onChanged: (text) =>
                editor.onValidityChanged?.call(editor.validate(text) == null),
          )
        : Semantics(
            liveRegion: true,
            label: widget.label,
            button: editor != null,
            hint: editor != null ? l10n.inputTapToEdit : null,
            child: InkWell(
              onTap: editor == null ? null : _startEdit,
              borderRadius: BorderRadius.circular(Tokens.radius),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Tokens.bigButton),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DecoratedBox(
                      // Dezente Linie: „hier kann man tippen“.
                      decoration: BoxDecoration(
                        border: editor == null
                            ? null
                            : Border(
                                bottom: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                  width: 2,
                                ),
                              ),
                      ),
                      child: Text(widget.value, style: big),
                    ),
                  ),
                ),
              ),
            ),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: theme.colorScheme.primary),
                  const SizedBox(width: Tokens.s),
                ],
                Expanded(
                  child: Text(widget.label, style: theme.textTheme.titleMedium),
                ),
                ?widget.action,
              ],
            ),
            const SizedBox(height: Tokens.s),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _wrap(widget.onDecrement),
                  icon: const Icon(Icons.remove_rounded),
                  tooltip: l10n.dialDecrease(widget.label),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(Tokens.bigButton),
                  ),
                ),
                const SizedBox(width: Tokens.s),
                Expanded(child: center),
                const SizedBox(width: Tokens.s),
                IconButton.filledTonal(
                  onPressed: _wrap(widget.onIncrement),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: l10n.dialIncrease(widget.label),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(Tokens.bigButton),
                  ),
                ),
              ],
            ),
            if (_editing && _error != null) ...[
              const SizedBox(height: Tokens.s),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
