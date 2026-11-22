#!/usr/bin/env bash
# Einmalig: android/ erzeugen, Berechtigungen setzen, Kiosk-Modus (Lock Task) aktivieren.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create . --platforms android --org de.concierge --project-name concierge_airbnb
M=android/app/src/main/AndroidManifest.xml
grep -q CAMERA "$M" || sed -i '0,/<application/s//<uses-permission android:name="android.permission.CAMERA"\/>\n    <uses-permission android:name="android.permission.RECORD_AUDIO"\/>\n    <uses-permission android:name="android.permission.INTERNET"\/>\n    <uses-permission android:name="android.permission.WAKE_LOCK"\/>\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"\/>\n    <application/' "$M"
K=$(find android/app/src/main -name MainActivity.kt)
cat > "$K" <<KT
package de.concierge.concierge_airbnb

import android.app.ActivityManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        if (am.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_NONE) startLockTask()
    }
}
KT
echo "Fertig. Für echten Kiosk ohne Bestätigungsdialog Gerät einmalig als Device Owner setzen:"
echo "  adb shell dpm set-device-owner de.concierge.concierge_airbnb/.AdminReceiver   (siehe README)"
echo "Alternativ: Android 'App-Pinning' in den Einstellungen aktivieren (Bildschirm anheften)."
