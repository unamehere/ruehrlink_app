/// Sekunden als Uhrzeit-Dauer: `0:30`, `4:30`, `1:05:00`.
String formatDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final rest = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$rest' : '$m:$rest';
}
