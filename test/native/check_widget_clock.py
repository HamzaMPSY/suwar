"""Run the pure Kotlin clock regression with the already-cached compiler; offline."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path.home() / '.gradle/caches/modules-2/files-2.1'


def jar(package):
    return str(next((CACHE / package).rglob('*.jar')))


compiler = jar('org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.20')
stdlib = jar('org.jetbrains.kotlin/kotlin-stdlib/2.2.20')
annotations = jar('org.jetbrains/annotations/23.0.0')
classpath = ':'.join([
    compiler, stdlib, annotations,
    jar('org.jetbrains.kotlin/kotlin-script-runtime/2.2.20'),
    jar('org.jetbrains.kotlin/kotlin-reflect/1.9.20'),
    jar('org.jetbrains.intellij.deps/trove4j/1.0.20200330'),
    jar('org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.9.0'),
])
java_home = (subprocess.check_output(
    ['/usr/libexec/java_home', '-v', '17'], text=True,
).strip() if Path('/usr/libexec/java_home').exists() else os.environ['JAVA_HOME'])
java = str(Path(java_home) / 'bin/java')
with tempfile.TemporaryDirectory(prefix='suwar-widget-clock-') as directory:
    output = str(Path(directory) / 'check.jar')
    subprocess.run([
        java, '-cp', classpath, 'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler',
        '-no-stdlib', '-no-reflect', '-jvm-target', '17', '-classpath',
        stdlib + ':' + annotations, '-d', output,
        'android/app/src/main/kotlin/com/suwar/suwar/PrayerWidgetClock.kt',
        'test/native/PrayerWidgetClockCheck.kt',
    ], cwd=ROOT, check=True)
    subprocess.run([
        java, '-cp', output + ':' + stdlib,
        'com.suwar.suwar.PrayerWidgetClockCheckKt',
    ], cwd=ROOT, check=True)
