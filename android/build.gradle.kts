allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

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

// ── Force tous les plugins (sous-projets Android) à compiler avec un
//    compileSdk/minSdk récent, requis par geocoding, image_picker, etc. ──
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            if (compileSdk == null || compileSdk!! < 36) {
                compileSdk = 36
            }
            defaultConfig {
                if (minSdk == null || minSdk!! < 23) {
                    minSdk = 23
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}