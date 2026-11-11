"""Ajusta a pasta android/ gerada por `flutter create` no CI.

1. Assinatura fixa com android-signing/debug.keystore (atualizações sem perder dados).
2. Core library desugaring (exigido pelo flutter_local_notifications).
3. Manifesto: permissões de notificação/alarme e receivers das notificações agendadas.

Funciona com build.gradle.kts (Kotlin) e build.gradle (Groovy).
"""
import pathlib
import re
import sys

app = pathlib.Path("android/app")
kts = app / "build.gradle.kts"
groovy = app / "build.gradle"
manifest = app / "src/main/AndroidManifest.xml"

DESUGAR_LIB = "com.android.tools:desugar_jdk_libs:2.1.4"

if kts.exists():
    path = kts
    s = path.read_text()
    signing = '''
    signingConfigs {
        create("fixa") {
            storeFile = file("../../android-signing/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
'''
    s, n = re.subn(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                   'signingConfig = signingConfigs.getByName("fixa")', s)
    desugar_flag = "isCoreLibraryDesugaringEnabled = true"
    compile_block = "\n    compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n    }\n"
    deps = f'\ndependencies {{\n    coreLibraryDesugaring("{DESUGAR_LIB}")\n}}\n'
elif groovy.exists():
    path = groovy
    s = path.read_text()
    signing = '''
    signingConfigs {
        fixa {
            storeFile file("../../android-signing/debug.keystore")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }
    }
'''
    s, n = re.subn(r'signingConfig\s+signingConfigs\.debug', 'signingConfig signingConfigs.fixa', s)
    desugar_flag = "coreLibraryDesugaringEnabled true"
    compile_block = "\n    compileOptions {\n        coreLibraryDesugaringEnabled true\n    }\n"
    deps = f"\ndependencies {{\n    coreLibraryDesugaring '{DESUGAR_LIB}'\n}}\n"
else:
    sys.exit("build.gradle não encontrado")

if n == 0:
    sys.exit("Não achei a linha de signingConfig do release no template do Flutter")

extra = signing
if re.search(r'^\s*compileOptions\s*\{', s, flags=re.M):
    s = re.sub(r'^(\s*compileOptions\s*\{)', lambda m: m.group(1) + "\n        " + desugar_flag, s, count=1, flags=re.M)
else:
    extra += compile_block

s, m = re.subn(r'^android\s*\{\s*$', lambda mt: mt.group(0) + extra, s, count=1, flags=re.M)
if m == 0:
    sys.exit('Não achei "android {" no build.gradle')
s += deps
path.write_text(s)
print(f"Assinatura fixa e desugaring configurados em {path}")

# ---- Manifesto -------------------------------------------------------------
mf = manifest.read_text()
perms = '''    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
'''
receivers = '''        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''
if "<application" not in mf or "</application>" not in mf:
    sys.exit("AndroidManifest.xml inesperado")
mf = mf.replace("<application", perms + "    <application", 1)
mf = mf.replace("</application>", receivers + "    </application>", 1)
manifest.write_text(mf)
print("Manifesto atualizado")
