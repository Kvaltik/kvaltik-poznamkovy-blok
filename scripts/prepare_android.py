"""Prepare generated Flutter Android project for HTTPS updates and stable release signing.

For publishing releases, put the signing materials in GitHub Actions secrets.
Do NOT commit any password or keystore into the repository.
"""
import base64
import os
from pathlib import Path
import re
import sys

manifest = Path("android/app/src/main/AndroidManifest.xml")
if not manifest.is_file():
    sys.exit("Missing generated Android manifest. Run flutter create first.")
source = manifest.read_text(encoding="utf-8")
permission = '<uses-permission android:name="android.permission.INTERNET" />'
if permission not in source:
    source, count = re.subn(r"(<manifest\b[^>]*>)", r"\1\n    " + permission, source, count=1)
    if count != 1:
        sys.exit("Could not add the Android INTERNET permission")
    manifest.write_text(source, encoding="utf-8")

publish = os.getenv("PUBLISH_RELEASE", "").lower() == "true"
names = ["ANDROID_KEYSTORE_BASE64", "ANDROID_KEY_ALIAS",
         "ANDROID_KEY_PASSWORD", "ANDROID_STORE_PASSWORD"]
values = {name: os.getenv(name, "") for name in names}
if not all(values.values()):
    if publish:
        sys.exit("Publishing requires all four Android signing secrets. "
                 "See README.md for setup. Build stopped to avoid a non-upgradable APK.")
    print("CI test build will use Flutter's default signing. Do not distribute this APK as a stable release.")
    sys.exit(0)

gradle = Path("android/app/build.gradle.kts")
if not gradle.is_file():
    sys.exit("Expected android/app/build.gradle.kts from Flutter create.")
content = gradle.read_text(encoding="utf-8")
debug_line = 'signingConfig = signingConfigs.getByName("debug")'
if debug_line not in content:
    sys.exit("Flutter Android Gradle template changed; not modifying signing automatically.")
if "    buildTypes {" not in content:
    sys.exit("Cannot find Flutter Android buildTypes block.")

keystore = Path("android/app/kvaltik-release.jks")
keystore.write_bytes(base64.b64decode(values["ANDROID_KEYSTORE_BASE64"], validate=True))
properties = Path("android/key.properties")
properties.write_text(
    "storePassword=" + values["ANDROID_STORE_PASSWORD"] + "\n"
    "keyPassword=" + values["ANDROID_KEY_PASSWORD"] + "\n"
    "keyAlias=" + values["ANDROID_KEY_ALIAS"] + "\n"
    "storeFile=kvaltik-release.jks\n",
    encoding="utf-8"
)

content = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + content
pos = content.find("\nandroid {")
if pos < 0:
    sys.exit("Cannot find Android Gradle configuration.")
content = content[:pos] + '''
val releaseSigningProperties = Properties().apply {
    load(FileInputStream(rootProject.file("key.properties")))
}
''' + content[pos:]
content = content.replace("    buildTypes {", '''
    signingConfigs {
        create("release") {
            keyAlias = releaseSigningProperties["keyAlias"] as String
            keyPassword = releaseSigningProperties["keyPassword"] as String
            storeFile = file(releaseSigningProperties["storeFile"] as String)
            storePassword = releaseSigningProperties["storePassword"] as String
        }
    }
    buildTypes {''', 1)
content = content.replace(debug_line, 'signingConfig = signingConfigs.getByName("release")', 1)
gradle.write_text(content, encoding="utf-8")
print("Configured stable Android release signing.")
