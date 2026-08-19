buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                
                // Try to load Mapbox token from .env file first
                var mapboxToken = ""
                val envFile = file("../.env")
                if (envFile.exists()) {
                    envFile.readLines().forEach {
                        val parts = it.split("=")
                        if (parts.size >= 2 && parts[0].trim() == "MAPBOX_DOWNLOADS_TOKEN") {
                            mapboxToken = parts[1].trim()
                        }
                    }
                }
                
                // Fallback to gradle.properties if not found
                if (mapboxToken.isEmpty() && providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").isPresent) {
                    mapboxToken = providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").get()
                }
                
                password = mapboxToken
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
