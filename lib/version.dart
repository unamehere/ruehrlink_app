/// App-Version, wird angezeigt unter „Mehr“. Bei jedem Release zusammen mit
/// `version:` in pubspec.yaml hochzählen (ein Test prüft, dass beide gleich sind).
/// Entwicklungsbuilds der Pipeline setzen sie per `--dart-define=APP_VERSION=0.6.2-dev.57`.
/// App und Firmware haben eigene Versionsnummern (siehe ruehrlink_esp/docs/updates.md).
const appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.6.1',
);
