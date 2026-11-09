"""Configura a assinatura do APK com a chave fixa do repositório (android-signing/debug.keystore).

Rodado no CI depois de `flutter create`. Funciona com build.gradle.kts (Kotlin) e build.gradle (Groovy).
"""
import pathlib
import re
import sys

app = pathlib.Path("android/app")
kts = app / "build.gradle.kts"
groovy = app / "build.gradle"

KTS_BLOCK = '''
    signingConfigs {
        create("fixa") {
            storeFile = file("../../android-signing/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
'''

GROOVY_BLOCK = '''
    signingConfigs {
        fixa {
            storeFile file("../../android-signing/debug.keystore")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }
    }
'''

if kts.exists():
    path, block = kts, KTS_BLOCK
    s = path.read_text()
    s, n = re.subn(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                   'signingConfig = signingConfigs.getByName("fixa")', s)
elif groovy.exists():
    path, block = groovy, GROOVY_BLOCK
    s = path.read_text()
    s, n = re.subn(r'signingConfig\s+signingConfigs\.debug', 'signingConfig signingConfigs.fixa', s)
else:
    sys.exit("build.gradle não encontrado")

if n == 0:
    sys.exit("Não achei a linha de signingConfig do release no template do Flutter")

# Insere o bloco signingConfigs logo depois de "android {"
s, m = re.subn(r'^android\s*\{\s*$', lambda mt: mt.group(0) + block, s, count=1, flags=re.M)
if m == 0:
    sys.exit('Não achei "android {" no build.gradle')

path.write_text(s)
print(f"Assinatura fixa configurada em {path}")
