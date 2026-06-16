# Flutter TTS Reader

A production-oriented Flutter reader application that converts PDF and TXT documents into synthesized audio with sentence-level highlighting, offline session persistence, and background audio playback.

## Overview

`flutter_tts_reader` is designed as a secure, responsive reading experience for touchscreen devices. It supports:

- PDF and plain text document ingestion
- Text-to-speech synthesis using `flutter_tts`
- Background audio playback via `audio_service`
- Sentence highlighting synchronized with playback
- Persistent resume state through local storage
- Parsing and text analysis through isolates for main-thread performance

## Core Architecture

The application is built around a modular runtime stack:

- `main.dart` initializes the audio service, starts a long-lived text isolate worker, configures audio session callbacks, and launches the UI.
- `ReaderAudioHandler` manages playback, page transitions, audio generation, and cache lifecycle.
- `SystemTtsService` wraps platform TTS synthesis and writes audio artifacts to temporary storage.
- `PdfParserService` and `TxtParserService` stream document pages one-by-one to avoid memory pressure.
- `SentenceHighlightReader` renders page text and dynamically highlights the active sentence during playback.
- `SessionManager` persists the last opened file and read page index with `shared_preferences`.

## Features

- **Multi-format support**: PDF and TXT import
- **Efficient parsing**: page-based text streaming for large documents
- **Playback continuity**: prefetches next page audio while current page plays
- **Session restoration**: restores last active document and page automatically
- **Background audio and media controls**: full audio service integration
- **Performance isolation**: text tokenization and sentence timing computation run off the main UI thread
- **Cache management**: temporary audio files are managed with a sliding window strategy

## Supported File Types

- `.pdf`
- `.txt`

## Dependencies

Key dependencies used by this project:

- `flutter_riverpod` for state management
- `flutter_tts` for text-to-speech conversion
- `audio_service` and `just_audio` for background audio playback
- `audio_session` for system audio session handling
- `file_picker` for file selection
- `path_provider` for secure application documents and cache storage
- `shared_preferences` for simple resume-state persistence
- `drift` and `sqlite3_flutter_libs` for local storage database support
- `archive` for file handling utilities

## Development Dependencies

- `flutter_test`
- `drift_dev`
- `build_runner`
- `flutter_lints`

## Getting Started

1. Install Flutter and ensure your environment is configured.
2. Open the project folder in VS Code or your preferred editor.
3. Run `flutter pub get` to install dependencies.
4. Launch the app on a connected device or emulator:

```bash
flutter run
```

## Project Structure

- `lib/main.dart`: app bootstrap and service initialization
- `lib/src/audio/`: audio handler and TTS service implementations
- `lib/src/parser/`: PDF and TXT parsing services
- `lib/src/services/`: session management, cache management, telemetry, and isolate worker logic
- `lib/src/ui/`: reader UI with sentence highlighting
- `lib/src/models/`: typed models used across the UI and services

## Notes

- PDF parsing uses a platform channel (`MethodChannel`) for native page extraction.
- The app is optimized for resource-constrained devices by streaming text and generating audio files on demand.
- Session restoration is designed to resume the last open file and page for a seamless return-to-reading experience.

## License

This repository does not include a license file. Add one if you plan to publish or share the project publicly.
