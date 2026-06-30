import org.gradle.api.Project
import java.time.LocalDate
import java.time.format.DateTimeFormatter

object BuildConfig {
    const val COMPILE_SDK = 37
    const val COMPILE_SDK_MINOR = 0
    const val TARGET_SDK = 37
    const val MIN_SDK = 26
    const val JDK_VERSION = 25

    const val VERSION_CODE = 520
}

// Get git commit count safely, compatible with configuration cache
fun Project.getGitCommitCount(): Int {
    return try {
        providers.exec {
            commandLine("git", "rev-list", "--count", "HEAD")
        }.standardOutput.asText.get().trim().toInt()
    } catch (_: Exception) {
        BuildConfig.VERSION_CODE
    }
}

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

    val baseVersionCode = getGitCommitCount()
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

// Get git commit hash safely, compatible with configuration cache
fun Project.getGitHash(): String {
    return try {
        providers.exec {
            commandLine("git", "rev-parse", "--short=7", "HEAD")
        }.standardOutput.asText.get().trim()
    } catch (_: Exception) {
        "unknown"
    }
}

// Get the date of the latest commit directly formatted as yy.MM
fun Project.getGitDate(): String {
    return try {
        providers.exec {
            commandLine("git", "log", "-1", "--format=%cd", "--date=format:%y.%m")
        }.standardOutput.asText.get().trim()
    } catch (_: Exception) {
        // Fallback to current date if git command fails
        LocalDate.now().format(DateTimeFormatter.ofPattern("yy.MM"))
    }
}

// Combine the manual version name or dynamic git date
fun Project.getBaseVersionName(): String {
    val manualVersionName = findProperty("VERSION_NAME") as String?
    return manualVersionName ?: getGitDate()
}
