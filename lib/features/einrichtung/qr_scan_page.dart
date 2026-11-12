import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../ui/theme.dart';

/// QR-Code vom Etikett der Brücke scannen. Gibt den gelesenen Text zurück.
///
/// `flutter_zxing` dekodiert lokal (zxing-cpp im Handy) – kein Google ML Kit,
/// kein Netzwerk. Die Kamera-Erlaubnis fragt das Kamera-Plugin beim Öffnen ab.
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  /// Öffnet den Scanner und liefert den Inhalt des QR-Codes (oder `null`).
  static Future<String?> open(BuildContext context) =>
      Navigator.of(context)
          .push<String>(MaterialPageRoute(builder: (_) => const QrScanPage()));

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupScanTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ReaderWidget(
              codeFormat: Format.qrCode,
              tryHarder: true,
              // Ohne eingebaute Schaltflächen (die nutzen das alte Material-Paket).
              showFlashlight: false,
              showToggleCamera: false,
              showGallery: false,
              scanDelay: const Duration(milliseconds: 300),
              onScan: (code) {
                final text = code.text;
                if (_done || !code.isValid || text == null) return;
                _done = true;
                Navigator.of(context).pop(text);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Tokens.l),
            child: Text(
              l10n.setupScanText,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
