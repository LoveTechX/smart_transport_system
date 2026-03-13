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

    // Compatibility shim for older plugins (for example flutter_windowmanager)
    // that still don't declare an Android namespace with AGP 8+.
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withId
            val getNamespace = androidExt.javaClass.methods.find {
                it.name == "getNamespace" && it.parameterCount == 0
            }
            val setNamespace = androidExt.javaClass.methods.find {
                it.name == "setNamespace" && it.parameterCount == 1
            }
            val currentNamespace = getNamespace?.invoke(androidExt) as? String
            if (currentNamespace.isNullOrBlank()) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                val manifestNamespace = if (manifestFile.exists()) {
                    Regex("package=\"([^\"]+)\"")
                        .find(manifestFile.readText())
                        ?.groupValues
                        ?.getOrNull(1)
                } else {
                    null
                }
                val resolvedNamespace = manifestNamespace
                    ?: "com.smarttransport.plugin.${project.name.replace('-', '_')}"
                setNamespace?.invoke(androidExt, resolvedNamespace)
            }
    }

    // Temporary compatibility shim for legacy flutter_windowmanager versions
    // that still reference removed v1 embedding Registrar APIs.
    if (project.name == "flutter_windowmanager") {
        tasks.matching { it.name == "preBuild" }.configureEach {
            doFirst {
                val pluginFile = file(
                    "${project.projectDir}/src/main/java/io/adaptant/labs/flutter_windowmanager/FlutterWindowManagerPlugin.java",
                )
                if (pluginFile.exists()) {
                    var source = pluginFile.readText()
                    source = source.replace(
                        "import io.flutter.plugin.common.PluginRegistry.Registrar;\n",
                        "",
                    )
                    source = source.replace(
                        Regex("(?s)\\n\\s*public static void registerWith\\(Registrar registrar\\) \\{.*?\\}\\n"),
                        "\n",
                    )
                    pluginFile.writeText(source)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
