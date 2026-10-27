"""Add TAMRA's permissions and settings to the generated android/ and ios/ folders.

Run from app/ after `flutter create` (the Bootstrap workflow does this). Safe to run again:
every change is only made when it is missing.

- Camera for the barcode scanner (T-24).
- Health Connect (Android) and HealthKit (iOS) read access for workouts and steps (T-53).

Still manual (needs the Apple developer account): Xcode → Runner → Signing & Capabilities →
"+ Capability" → HealthKit.
"""

import re
import sys
from pathlib import Path

CAMERA_TEXT = "TAMRA uses the camera to scan barcodes of foods."
HEALTH_READ_TEXT = "TAMRA reads your workouts and steps to show your calorie balance."
HEALTH_WRITE_TEXT = "TAMRA can save what you eat to Apple Health if you allow it."

ANDROID_PERMISSIONS = [
    "android.permission.CAMERA",
    "android.permission.health.READ_EXERCISE",
    "android.permission.health.READ_STEPS",
    "android.permission.health.READ_ACTIVE_CALORIES_BURNED",
    "android.permission.health.READ_DISTANCE",
    "android.permission.ACTIVITY_RECOGNITION",
]

HEALTH_QUERIES = """    <queries>
        <package android:name="com.google.android.apps.healthdata" />
        <intent>
            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
        </intent>
    </queries>
"""

PERMISSION_ALIAS = """        <!-- Health Connect: link to the privacy policy -->
        <activity-alias
            android:name="ViewPermissionUsageActivity"
            android:exported="true"
            android:targetActivity=".MainActivity"
            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
            <intent-filter>
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
                <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
            </intent-filter>
        </activity-alias>
"""

RATIONALE_FILTER = """            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>
"""


def configure_android(root: Path) -> None:
    """Permissions, Health Connect entries, FlutterFragmentActivity and minSdk 26."""
    manifest_path = root / "android/app/src/main/AndroidManifest.xml"
    manifest = manifest_path.read_text(encoding="utf-8")
    for permission in ANDROID_PERMISSIONS:
        if permission not in manifest:
            line = f'    <uses-permission android:name="{permission}" />\n'
            manifest = manifest.replace("    <application", line + "    <application", 1)
    if "com.google.android.apps.healthdata" not in manifest:
        manifest = manifest.replace("</manifest>", HEALTH_QUERIES + "</manifest>", 1)
    if "ViewPermissionUsageActivity" not in manifest:
        closing = "    </application>"
        manifest = manifest.replace(closing, PERMISSION_ALIAS + closing, 1)
    if "ACTION_SHOW_PERMISSIONS_RATIONALE\" />\n            </intent-filter>" not in manifest:
        # first </activity> belongs to .MainActivity in the Flutter template
        closing = "        </activity>"
        manifest = manifest.replace(closing, RATIONALE_FILTER + closing, 1)
    manifest_path.write_text(manifest, encoding="utf-8")

    for activity in (root / "android/app/src/main").rglob("MainActivity.kt"):
        code = activity.read_text(encoding="utf-8")
        code = code.replace(
            "import io.flutter.embedding.android.FlutterActivity",
            "import io.flutter.embedding.android.FlutterFragmentActivity",
        ).replace(": FlutterActivity()", ": FlutterFragmentActivity()")
        activity.write_text(code, encoding="utf-8")

    for gradle in (root / "android/app").glob("build.gradle*"):
        text = gradle.read_text(encoding="utf-8")
        text = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 26", text)
        text = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 26", text)
        gradle.write_text(text, encoding="utf-8")


def configure_ios(root: Path) -> None:
    """Usage texts in Info.plist (camera, health)."""
    plist_path = root / "ios/Runner/Info.plist"
    plist = plist_path.read_text(encoding="utf-8")
    entries = {
        "NSCameraUsageDescription": CAMERA_TEXT,
        "NSHealthShareUsageDescription": HEALTH_READ_TEXT,
        "NSHealthUpdateUsageDescription": HEALTH_WRITE_TEXT,
    }
    for key, text in entries.items():
        if f"<key>{key}</key>" not in plist:
            entry = f"<dict>\n\t<key>{key}</key>\n\t<string>{text}</string>"
            plist = plist.replace("<dict>", entry, 1)
    plist_path.write_text(plist, encoding="utf-8")


def main() -> int:
    """Configure both platforms in the app folder given as argument (default: current)."""
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    configure_android(root)
    configure_ios(root)
    print("Android and iOS configured for camera and health data.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
