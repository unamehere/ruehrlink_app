import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/storage/app_storage.dart';

/// Schriftgröße der App (Mehr → Schriftgröße). Wirkt zusätzlich zur
/// Schriftgröße des Handys. „Mittel“ ist der bisherige Stand.
enum TextSize {
  small(0.85),
  medium(1.0),
  large(1.15);

  const TextSize(this.factor);
  final double factor;
}

final textSizeProvider = NotifierProvider<TextSizeNotifier, TextSize>(
  TextSizeNotifier.new,
);

class TextSizeNotifier extends Notifier<TextSize> {
  @override
  TextSize build() {
    final i = ref.read(appStorageProvider).textSize;
    return TextSize.values[i.clamp(0, TextSize.values.length - 1)];
  }

  Future<void> set(TextSize size) async {
    state = size;
    await ref.read(appStorageProvider).setTextSize(size.index);
  }
}

/// Legt die gewählte Schriftgröße über die des Handys.
class AppTextScale extends ConsumerWidget {
  const AppTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factor = ref.watch(textSizeProvider).factor;
    if (factor == 1.0) return child;
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: _Scaled(mq.textScaler, factor)),
      child: child,
    );
  }
}

class _Scaled extends TextScaler {
  const _Scaled(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _Scaled && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
