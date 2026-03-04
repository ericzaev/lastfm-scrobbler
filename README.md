# MusicScrobbler (macOS Last.fm Client)

A modern, native macOS application built with SwiftUI that scrobbles music from the macOS "Music" app to Last.fm. It features a sleek interface inspired by the Last.fm website, providing real-time tracking, profile statistics, and library discovery.

## 🚀 Key Features

- **Full Scrobbling Engine**: Automatically detects track changes in the macOS Music app and submits scrobbles following Last.fm's guidelines (50% duration or 4 minutes).
- **Live "Now Playing" Status**: Instantly updates your Last.fm profile with your current track using the `track.updateNowPlaying` API.
- **Web-Inspired UI**: A high-fidelity SwiftUI interface featuring Last.fm's signature crimson aesthetic, hero headers, and photo-centric grid galleries.
- **Deep Library Discovery**: 
    - **Detailed Views**: Click on any Artist, Album, or Track to see full wiki descriptions and high-res artwork.
    - **Similar Recommendations**: Discover new music with horizontal "Similar Artists" and "Similar Tracks" feeds.
    - **Global Profile**: View your total playcounts, registration date, and recent history.
- **Secure Authentication**: Implements the official Last.fm Web Authentication flow. Your API credentials and session keys are persisted locally in your macOS settings.
- **Native Sidebar Navigation**: Standard macOS split-view layout for easy access to your Library, Top Artists, and Top Albums.

## 🛠 Prerequisites

- **macOS 13.0 (Ventura)** or later.
- **macOS Music App** (formerly iTunes) must be used for playback.
- **Last.fm API Account**: You will need an API Key and Shared Secret (available at [last.fm/api/account/create](https://www.last.fm/api/account/create)).

## 📦 Build & Run

### Development Mode
To build and run the project immediately from the source:
```bash
swift run
```

### Create Native .app Bundle
To package the project into a proper macOS application with an icon:
1.  **Build in Release Mode**:
    ```bash
    swift build -c release
    ```
2.  **Create the Bundle Structure**:
    ```bash
    mkdir -p MusicScrobbler.app/Contents/MacOS
    mkdir -p MusicScrobbler.app/Contents/Resources
    ```
3.  **Copy the Binary**:
    ```bash
    cp .build/release/MusicLastFMPlugin MusicScrobbler.app/Contents/MacOS/MusicScrobbler
    ```
4.  **Generate Icon**: (Ensure you have a `logo.png` in the root)
    -   The project includes automated scripts to convert a PNG into a native `.icns` file for the bundle.

## ⚙️ Setup

1.  **Launch the app**: On first run, you will be prompted to enter your **API Key** and **Shared Secret**.
2.  **Connect**: Click "Connect to Last.fm". The app will open your web browser for official authorization.
3.  **Authorize**: Click "Yes, allow access" on the Last.fm website, then return to the app and click "I've Authorized The App".
4.  **Scrobble**: Once logged in, simply play music in the Apple Music app. The scrobbler will handle the rest in the background.

## 🔒 Permissions

The first time the app attempts to read your music status, macOS will ask for **Automation** permissions. You must allow "MusicScrobbler" to control "Music" for the scrobbling logic to work.

## 📂 Project Structure

- `Sources/MusicLastFMPlugin/MusicLastFMPlugin.swift`: The unified source containing the SwiftUI views, API Manager, and AppleScript bridge.
- `MusicScrobbler.app/`: The generated native macOS application bundle.
- `Package.swift`: Swift Package Manager configuration targeting macOS 13.
