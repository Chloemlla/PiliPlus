import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

val targetAndroidSdk = 37
extra["targetAndroidSdk"] = targetAndroidSdk

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            name = "GitHubPackagesProjectLumen"
            url = uri("https://maven.pkg.github.com/Chloemlla/Project-Lumen")
            credentials {
                username = providers.gradleProperty("gpr.user").orNull
                    ?: System.getenv("GITHUB_ACTOR")
                    ?: ""
                password = providers.gradleProperty("gpr.key").orNull
                    ?: System.getenv("GITHUB_TOKEN")
                    ?: System.getenv("GH_TOKEN")
                    ?: ""
            }
        }
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
    afterEvaluate {
        if (project.extensions.findByName("android") != null) {
            val androidExtension =
                project.extensions.getByName("android") as com.android.build.gradle.BaseExtension

            if (androidExtension.namespace == null) {
                androidExtension.namespace = project.group.toString()
            }

            androidExtension.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }

            project.tasks.withType<KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }

            val pluginCompileSdkStr = androidExtension.compileSdkVersion
            val pluginCompileSdk = pluginCompileSdkStr
                ?.removePrefix("android-")
                ?.toIntOrNull()
            if (pluginCompileSdk != null && pluginCompileSdk < targetAndroidSdk) {
                project.logger.info(
                    "Overriding compileSdk version in Flutter plugin: ${project.name} " +
                            "from $pluginCompileSdk to $targetAndroidSdk"
                )
                androidExtension.setCompileSdkVersion(targetAndroidSdk)
            }
        }

        project.buildDir = File(rootProject.buildDir, project.name)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
