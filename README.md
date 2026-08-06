<div align="center">

# RiverFlow

<u>Native Customizable File Manager Engine for MacOS</u>

## Overview

![Version](https://img.shields.io/badge/Version-0.1.0-purple)
![Platform](https://img.shields.io/badge/Platform-macOS%2014.0+-black?logo=apple)
![Language](https://img.shields.io/badge/Language-Swift%206-orange?logo=swift)
![Architecture](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon/Intel)-blue)
![License](https://img.shields.io/badge/RKNCSL-1.1-purple)
[![codecov](https://codecov.io/github/Predsu/RiverFlow/branch/main/graph/badge.svg)](https://codecov.io/github/Predsu/RiverFlow)
<img src="https://img.shields.io/github/last-commit/Predsu/RiverFlow?style=flat&logo=git&logoColor=white&color=0080ff" alt="last-commit">
<img alt="GitHub commit activity" src="https://img.shields.io/github/commit-activity/w/Predsu/RiverFlow">
<img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/Predsu/RiverFlow">

<br><br>

RiverFlow is an experimental native file manager designed for developers and advanced macOS users.

Its goal is to provide a customizable alternative to Finder with developer-oriented actions, familiar file-management controls and a fully native macOS interface. RiverFlow is written in Swift using SwiftUI and AppKit, without depending on a cross-platform UI framework.

> [!IMPORTANT]
> RiverFlow is currently in early development. Features, interface elements and project requirements may change between releases.

</div>

---

## Features

### File management

* Browse directories using a native sidebar and file view.
* Display files using grid or list layouts.
* Sort files by name, modification date or size.
* Create new files and directories.
* Rename files and directories.
* Copy, cut and paste multiple selected items.
* Move files to the Trash.
* Drag and drop files between directories.
* Create a new folder containing the selected files.
* Show or hide hidden files.
* Undo and redo supported file operations.

### Developer tools

* Open the current directory in Terminal.
* Open the current directory in Visual Studio Code.
* Copy regular filesystem paths.
* Copy shell-escaped paths.
* Calculate and copy SHA-256 checksums.
* Compress selected files and directories into ZIP archives.
* Open files using a manually selected application.
* Reveal selected items in Finder.

### Native macOS experience

* SwiftUI-based interface using `NavigationSplitView`.
* Native AppKit file operations and system pasteboard integration.
* Standard macOS keyboard commands for copying, cutting and pasting.
* Command-click and Shift-click multi-selection.
* Selection rectangle support.
* Native drag-and-drop interactions.
* System thumbnails and file metadata.
* Integrated sound effects and launch splash screen.
* Native support for Apple silicon and Intel Macs.

---

## Screenshots

Screenshots will be added as the interface develops.

<!--
<p align="center">
  <img src="docs/images/riverflow-main-window.png" alt="RiverFlow main window" width="850">
</p>
-->

<img width="1012" height="616" alt="Zrzut ekranu 2026-08-6 o 16 43 20" src="https://github.com/user-attachments/assets/de8383b4-096a-4f8e-a9b2-5a63a2afd0ac" />
<img width="1012" height="616" alt="Zrzut ekranu 2026-08-6 o 16 43 36" src="https://github.com/user-attachments/assets/2bf5815d-7648-40a3-a761-f5d6abaff4e8" />
<img width="1012" height="616" alt="Zrzut ekranu 2026-08-6 o 16 43 49" src="https://github.com/user-attachments/assets/de8cdc6e-095c-4e2c-980c-56a71c56c414" />
<img width="1012" height="616" alt="Zrzut ekranu 2026-08-6 o 16 44 08" src="https://github.com/user-attachments/assets/0e694892-4010-409a-8d41-490129ef3f4e" />

---

## Requirements

### Running RiverFlow

| Requirement        | Version                                                  |
| ------------------ | -------------------------------------------------------- |
| Operating system   | macOS 14 Sonoma or newer                                 |
| Architecture       | Apple silicon or Intel                                   |

### Development

| Requirement | Version             |
| ----------- | ------------------- |
| macOS       | 14 Sonoma or newer  |
| Xcode       | 16.0 or newer       |
| Swift       | 6.0 |
| Git         | Any recent version  |

RiverFlow currently has no external package dependencies.

---

## Building from Source

Clone the repository:

```bash
git clone https://github.com/Predsu/RiverFlow.git
cd RiverFlow
```

Open the Xcode project:

```bash
open RiverFlow.xcodeproj
```

In Xcode:

1. Select the **RiverFlow** scheme.
2. Select **My Mac** as the destination.
3. Press <kbd>⌘</kbd> + <kbd>R</kbd> to build and run the application.

You may need to configure your own development team under:

```text
RiverFlow target → Signing & Capabilities
```

---

## Installation & First Launch

Reviewers and users **do not need to compile this project from source**. Full version of the app will be distributed using external system but for the Stardance project purposes users can follow these steps to get the app's demo running in seconds:

1. Go to the [Releases Page](https://github.com/Predsu/RiverFlow/releases/latest) and download the `RiverFlowDemo.dmg` file.
2. Double-click the downloaded `.dmg` file and drag **RiverFlow** into your **Applications** folder.
3. Open your Applications folder and launch the app.

### Overriding macOS Gatekeeper (Fixing the "Developer Cannot Be Verified" Error)

Because this app is an open-source project and is not distributed through the Mac App Store, macOS Gatekeeper might block the first launch with a warning. To safely bypass this:

1. Try to open the app normally. You'll get the warning about security.
2. Open System Settings → Privacy & Security.
3. Scroll to the bottom. You'll see a message that the app was blocked. Click Open Anyway.
4. Enter your password or use Touch ID.
5. Confirm Open.
6. The app will now launch successfully.

---

## Running Tests

RiverFlow contains separate unit-test and UI-test targets.

Run all tests from Xcode with:

```text
Product → Test
```

or press:

```text
⌘U
```

Tests can also be started from the command line:

```bash
xcodebuild test \
  -project RiverFlow.xcodeproj \
  -scheme RiverFlow \
  -destination 'platform=macOS'
```

---

## Project Structure

```text
RiverFlow/
├── .github/                   # GitHub configuration and workflows
├── RiverFlow.icon/            # Application icon project
├── RiverFlow.xcodeproj/       # Xcode project configuration
├── RiverFlow/
│   ├── Assets.xcassets/       # Images, colors and application assets
│   ├── Components.swift       # Reusable interface components
│   ├── ContentView.swift      # Main file-manager interface
│   ├── Enums.swift            # View, sorting and sidebar definitions
│   ├── FileItem.swift         # File and directory data model
│   ├── FolderViewModel.swift  # File operations and directory state
│   ├── RiverFlowApp.swift     # Application entry point
│   ├── SplashView.swift       # Launch splash overlay
│   └── RiverFlow.entitlements
├── RiverFlowTests/            # Unit tests
├── RiverFlowUITests/          # UI tests
├── EULA.md                    # End-user licence agreement
├── LICENSE                    # Source-code licence
└── README.md
```

### Architecture

RiverFlow uses a lightweight view-model architecture:

* `FileItem` represents a file or directory and its metadata.
* `FolderViewModel` manages the active directory, selection state and filesystem operations.
* `ContentView` builds the main SwiftUI interface and connects user actions to the view model.
* `Components.swift` contains reusable views, file tiles, list rows and supporting macOS integrations.

File operations are performed locally using Foundation and AppKit APIs.

---

## Privacy

RiverFlow is designed as a local desktop application.

* File browsing and management happen directly on the Mac.
* File contents are not uploaded to an external service by RiverFlow.
* SHA-256 checksums are calculated locally using CryptoKit.
* The application does not require an account or cloud connection.

As with any file manager, RiverFlow needs access to the directories and files you choose to manage. macOS may request additional permissions for protected locations.

---

## Current Status

RiverFlow is under active development and should currently be treated as experimental software.

Some planned areas of development include:

* Improved navigation history.
* Search and filtering.
* Expanded file previews.
* More customization options.
* Improved error presentation.
* Additional keyboard shortcuts.
* Broader automated test coverage.
* Signed and packaged release builds.

Development progress and known problems can be followed through the [issue tracker](https://github.com/Predsu/RiverFlow/issues).

---

## Contributing

Bug reports, feature proposals and pull requests are welcome.

Before contributing:

1. Search the existing issues to avoid duplicates.
2. Open an issue describing significant changes before implementing them.
3. Keep pull requests focused on one feature or fix.
4. Add or update tests where appropriate.
5. Verify that the project builds and tests successfully in Xcode.

By contributing, you agree that your contribution may be distributed under the repository’s applicable licensing terms.

---

## Reporting Bugs

When reporting a bug, include:

* Your macOS version.
* Your Mac architecture: Apple silicon or Intel.
* The RiverFlow version or commit SHA.
* Steps needed to reproduce the problem.
* The expected and actual result.
* Relevant screenshots or console output.

Please avoid including private filenames, paths or other sensitive information in public reports.

---

## Licence

RiverFlow is distributed under the terms contained in the repository’s [`LICENSE`](LICENSE) file (RKNCSL 1.1).

Use of compiled application builds is additionally governed by the [`EULA.md`](EULA.md) file.

Review both documents before using, modifying, redistributing or commercially distributing RiverFlow.

---

## Acknowledgements

RiverFlow is part of the **Shrimple Project** and is developed as an exploration of native macOS application development and customizable file-management workflows.

---

<div align="center">

Made with Swift for macOS.

[Report a Bug](https://github.com/Predsu/RiverFlow/issues/new) ·
[Request a Feature](https://github.com/Predsu/RiverFlow/issues/new)

</div>
