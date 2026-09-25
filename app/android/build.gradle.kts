allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// agora_rtc_engine's own android/build.gradle hardcodes compileSdkVersion 31
// via safeExtGet('compileSdkVersion', 31) unless this rootProject.ext value is
// set - its AndroidX dependencies (fragment, window, activity, ...) require a
// consumer compiled against API 34+, so the plugin's build fails without this.
rootProject.extra["compileSdkVersion"] = 37

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
