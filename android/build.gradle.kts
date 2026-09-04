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

// ── Force TOUS les plugins Android à compiler avec compileSdk 36 / minSdk 23.
//    Appliqué APRÈS évaluation de chaque sous-projet, sinon la valeur du
//    plugin (android-33) écrase la nôtre (cas de geocoding_android). ──
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            project.extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileSdk = 36
                defaultConfig {
                    if (minSdk == null || minSdk!! < 23) {
                        minSdk = 23
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}