# Preserve Flutter Engine and platform channel messaging infrastructure
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }

# Protect your explicit custom native PDF MethodChannel package
-keep class io.github.christianbihasa.pdf_parser.** { *; }

# Preserve Ryan Heise's audio_service background execution framework
-keep class com.ryanheise.audio_service.** { *; }
-keep class class com.ryanheise.audio_service.AudioService { *; }

# Prevent JustAudio native players from dropping underlying media codecs
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.google.android.exoplayer2.** { *; }