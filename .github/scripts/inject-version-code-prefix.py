import re
from pathlib import Path


build_config = Path("build-plugins/src/main/kotlin/BuildConfig.kt")
app_gradle = Path("app/build.gradle.kts")

version_code_helper = r'''
fun Project.getVersionCode(): Int {
    val explicitVersionCode = providers.gradleProperty("VERSION_CODE")
        .orElse(providers.environmentVariable("VERSION_CODE"))
        .orNull
        ?.trim()
        ?.takeIf { it.isNotEmpty() }

    if (explicitVersionCode != null) {
        return explicitVersionCode.toIntOrNull()
            ?: error("VERSION_CODE must be an integer: $explicitVersionCode")
    }

    val baseVersionCode = providers.exec {
        commandLine("git", "rev-list", "--count", "HEAD")
    }.standardOutput.asText.get().trim().toIntOrNull()
        ?: error("Could not determine git commit count")
    val versionCodePrefix = providers.gradleProperty("VERSION_CODE_PREFIX")
        .orElse(providers.environmentVariable("VERSION_CODE_PREFIX"))
        .orNull
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?: return baseVersionCode

    require(versionCodePrefix.all { it.isDigit() }) {
        "VERSION_CODE_PREFIX must contain only digits: $versionCodePrefix"
    }

    val prefixedVersionCode = "$versionCodePrefix$baseVersionCode".toLong()
    require(prefixedVersionCode <= Int.MAX_VALUE) {
        "Prefixed VERSION_CODE $prefixedVersionCode exceeds ${Int.MAX_VALUE}"
    }

    return prefixedVersionCode.toInt()
}
'''

build_config_text = build_config.read_text(encoding="utf-8")
if "fun Project.getVersionCode()" not in build_config_text:
    marker = "\n// Get git commit hash safely"
    if marker not in build_config_text:
        raise SystemExit("Could not find insertion point in BuildConfig.kt")
    build_config.write_text(
        build_config_text.replace(marker, "\n" + version_code_helper.strip() + "\n" + marker, 1),
        encoding="utf-8",
    )

app_gradle_text = app_gradle.read_text(encoding="utf-8")
if "versionCode = project.getVersionCode()" not in app_gradle_text:
    updated_app_gradle_text, replacements = re.subn(
        r"^(\s*versionCode\s*=\s*).+$",
        r"\1project.getVersionCode()",
        app_gradle_text,
        count=1,
        flags=re.MULTILINE,
    )
    if replacements:
        app_gradle.write_text(updated_app_gradle_text, encoding="utf-8")
    else:
        raise SystemExit("Could not find versionCode assignment in app/build.gradle.kts")
