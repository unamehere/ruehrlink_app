import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../ui/hilfe_knopf.dart';
import '../einrichtung/maschine_koppeln_anleitung.dart';

// Alle Hilfe-Fenster der App an einem Ort. Die Texte stehen in app_de.arb als Block `help…`
// (Übersicht zum Gegenlesen: docs/hilfetexte.md).

/// Rezepte-Tab: wie Rezepte funktionieren.
Hilfe hilfeRezepte(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpWhereText,
      titel: l10n.helpWhereTitle,
      icon: Icons.wifi_tethering_rounded,
    ),
    HilfeEintrag(
      l10n.helpIngredientsText,
      titel: l10n.helpIngredientsTitle,
      icon: Icons.format_list_bulleted_rounded,
    ),
    HilfeEintrag(
      l10n.helpToolText,
      titel: l10n.helpToolTitle,
      icon: Icons.swap_horiz_rounded,
    ),
    HilfeEintrag(
      l10n.helpMachineText,
      titel: l10n.helpMachineTitle,
      icon: Icons.blender_rounded,
    ),
    HilfeEintrag(
      l10n.helpWeighText,
      titel: l10n.helpWeighTitle,
      icon: Icons.scale_rounded,
    ),
    HilfeEintrag(
      l10n.helpServingsText,
      titel: l10n.helpServingsTitle,
      icon: Icons.people_alt_outlined,
    ),
  ],
);

/// Rezept-Editor: Einheiten, Zutaten beim Schritt, Werkzeug, Maschinenschritt.
Hilfe hilfeEditor(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpEditorTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpUnitsText,
      titel: l10n.helpUnitsTitle,
      icon: Icons.scale_rounded,
    ),
    HilfeEintrag(
      l10n.helpIngredientsText,
      titel: l10n.helpIngredientsTitle,
      icon: Icons.format_list_bulleted_rounded,
    ),
    HilfeEintrag(
      l10n.helpToolText,
      titel: l10n.helpToolTitle,
      icon: Icons.swap_horiz_rounded,
    ),
    HilfeEintrag(
      l10n.helpEditorMachineText,
      titel: l10n.helpMachineTitle,
      icon: Icons.blender_rounded,
    ),
  ],
);

/// Einrichtung, Schritt „Rührlink finden“: Bluetooth und Code.
Hilfe hilfeEinrichtungBluetooth(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpSetupBluetoothTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpSetupBluetoothOnlyText,
      titel: l10n.helpSetupBluetoothOnlyTitle,
      icon: Icons.bluetooth_rounded,
    ),
    HilfeEintrag(
      l10n.helpSetupCodeText,
      titel: l10n.helpSetupCodeTitle,
      icon: Icons.qr_code_rounded,
    ),
    HilfeEintrag(
      l10n.helpSetupNotFoundText,
      titel: l10n.helpSetupNotFoundTitle,
      icon: Icons.power_rounded,
    ),
  ],
);

/// Einrichtung, Schritt „Heim-WLAN“.
Hilfe hilfeEinrichtungWlan(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpSetupWifiTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpSetupWifiBandText,
      titel: l10n.helpSetupWifiBandTitle,
      icon: Icons.wifi_rounded,
    ),
    HilfeEintrag(
      l10n.helpSetupWifiPasswordText,
      titel: l10n.helpSetupWifiPasswordTitle,
      icon: Icons.lock_outline_rounded,
    ),
  ],
);

/// Einrichtung, Schritt „Maschine koppeln“ – mit Knopf zur Bildanleitung.
Hilfe hilfeMaschineKoppeln(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpSetupMachineTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpSetupMachineHowText,
      titel: l10n.helpSetupMachineHowTitle,
      icon: Icons.settings_rounded,
    ),
    HilfeEintrag(
      l10n.helpSetupMachineWhatText,
      titel: l10n.helpSetupMachineWhatTitle,
      icon: Icons.sync_alt_rounded,
    ),
    HilfeEintrag(
      l10n.helpSetupMachineRetryText,
      titel: l10n.helpSetupMachineRetryTitle,
      icon: Icons.refresh_rounded,
    ),
  ],
  aktion: (
    label: l10n.helpSetupMachineGuide,
    icon: Icons.photo_library_outlined,
    onTap: zeigeMaschineKoppelnAnleitung,
  ),
);

/// Neues Handy koppeln: warum ein anderes Handy bestätigt.
Hilfe hilfeKopplungBestaetigen(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpPairTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpPairWhyText,
      titel: l10n.helpPairWhyTitle,
      icon: Icons.phonelink_lock_rounded,
    ),
    HilfeEintrag(
      l10n.helpPairHowText,
      titel: l10n.helpPairHowTitle,
      icon: Icons.timer_outlined,
    ),
  ],
);

/// Maschinen-Tab: die Regler, Senden und Stopp.
Hilfe hilfeMaschine(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpMachineTabTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpTempText,
      titel: l10n.helpTempTitle,
      icon: Icons.thermostat_rounded,
    ),
    HilfeEintrag(
      l10n.helpTimeText,
      titel: l10n.helpTimeTitle,
      icon: Icons.timer_outlined,
    ),
    HilfeEintrag(
      l10n.helpSpeedText,
      titel: l10n.helpSpeedTitle,
      icon: Icons.speed_rounded,
    ),
    HilfeEintrag(
      l10n.helpStirText,
      titel: l10n.helpStirTitle,
      icon: Icons.autorenew_rounded,
    ),
    HilfeEintrag(
      l10n.helpSendText,
      titel: l10n.helpSendTitle,
      icon: Icons.touch_app_rounded,
    ),
    HilfeEintrag(
      l10n.helpStopText,
      titel: l10n.helpStopTitle,
      icon: Icons.stop_circle_outlined,
    ),
  ],
);

/// Waage: Tara, „verbindet …“, automatisches Öffnen.
Hilfe hilfeWaage(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpScaleTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpScaleTareText,
      titel: l10n.helpScaleTareTitle,
      icon: Icons.exposure_zero_rounded,
    ),
    HilfeEintrag(
      l10n.helpScaleWaitText,
      titel: l10n.helpScaleWaitTitle,
      icon: Icons.hourglass_bottom_rounded,
    ),
    HilfeEintrag(
      l10n.helpScalePopupText,
      titel: l10n.helpScalePopupTitle,
      icon: Icons.open_in_full_rounded,
    ),
  ],
);

/// Kochen-Tab: Programme und Assistenten.
Hilfe hilfeProgramme(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpProgramsTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpProgramsText,
      titel: l10n.programsTitle,
      icon: Icons.playlist_play_rounded,
    ),
    HilfeEintrag(
      l10n.helpProgramsRestText,
      titel: l10n.helpProgramsRestTitle,
      icon: Icons.pause_circle_outline_rounded,
    ),
    HilfeEintrag(
      l10n.helpAssistantsText,
      titel: l10n.helpAssistantsTitle,
      icon: Icons.auto_awesome_outlined,
    ),
  ],
);

/// Kochmodus: Blättern, Maschinenschritte, Wiegen, Werkzeug.
Hilfe hilfeKochmodus(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpCookTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpCookPagesText,
      titel: l10n.helpCookPagesTitle,
      icon: Icons.swipe_rounded,
    ),
    HilfeEintrag(
      l10n.helpCookMachineText,
      titel: l10n.helpCookMachineTitle,
      icon: Icons.blender_rounded,
    ),
    HilfeEintrag(
      l10n.helpCookWeighText,
      titel: l10n.helpWeighTitle,
      icon: Icons.scale_rounded,
    ),
    HilfeEintrag(
      l10n.helpCookToolText,
      titel: l10n.helpToolTitle,
      icon: Icons.swap_horiz_rounded,
    ),
  ],
);

/// Update-Seite: Datei, Prüfung, Rückfall auf die alte Version.
Hilfe hilfeUpdate(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpUpdateTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpUpdateFileText,
      titel: l10n.helpUpdateFileTitle,
      icon: Icons.file_open_outlined,
    ),
    HilfeEintrag(
      l10n.helpUpdateCheckText,
      titel: l10n.helpUpdateCheckTitle,
      icon: Icons.verified_outlined,
    ),
    HilfeEintrag(
      l10n.helpUpdateRollbackText,
      titel: l10n.helpUpdateRollbackTitle,
      icon: Icons.restore_rounded,
    ),
    HilfeEintrag(
      l10n.helpUpdateWhenText,
      titel: l10n.helpUpdateWhenTitle,
      icon: Icons.schedule_rounded,
    ),
  ],
);

/// Verbindung und „nicht erreichbar“.
Hilfe hilfeVerbindung(AppLocalizations l10n) => Hilfe(
  titel: l10n.helpConnectionTitle,
  eintraege: [
    HilfeEintrag(
      l10n.helpConnectionLocalText,
      titel: l10n.helpConnectionLocalTitle,
      icon: Icons.home_outlined,
    ),
    HilfeEintrag(
      l10n.helpConnectionUnreachableText,
      titel: l10n.helpConnectionUnreachableTitle,
      icon: Icons.wifi_off_rounded,
    ),
    HilfeEintrag(
      l10n.helpConnectionMachineText,
      titel: l10n.helpConnectionMachineTitle,
      icon: Icons.link_off_rounded,
    ),
    HilfeEintrag(
      l10n.helpConnectionPhoneText,
      titel: l10n.helpConnectionPhoneTitle,
      icon: Icons.smartphone_rounded,
    ),
  ],
);
