<div align="center">

# RIVERFLOW

<em>Transforming file management for developers</em>

![Version](https://img.shields.io/badge/Version-none-red)
![Platform](https://img.shields.io/badge/Platform-macOS%2014.0+-black?logo=apple)
![Architecture](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon/Intel)-blue)
![License](https://img.shields.io/badge/License-RKNCSL%201.1-green)
[![codecov](https://codecov.io/github/Predsu/RiverFlow/branch/main/graph/badge.svg)](https://codecov.io/github/Predsu/RiverFlow)
<img alt="GitHub commit activity" src="https://img.shields.io/github/commit-activity/w/Predsu/RiverFlow">
<img src="https://img.shields.io/github/last-commit/Predsu/RiverFlow?style=flat&logo=git&logoColor=white&color=0080ff" alt="last-commit">
<img alt="GitHub Issues" src="https://img.shields.io/github/issues/Predsu/RiverFlow">

## Overview

RiverFlow is an experimental native file manager designed for developers and advanced macOS users.

Its goal is to provide a customizable alternative to other file managers with developer-oriented actions, familiar file-management controls and a fully native macOS interface. RiverFlow is written in Swift using SwiftUI and AppKit, without depending on a cross-platform UI framework.

The project is targeted to work with macOS 14 or higher and Apple Sillicon as well as Intel-based devices (however in restricted mode it can run on macOS 12 or higher with decreased functionalities).

</div>

---

## Features

File management

- Browse directories using a native sidebar and file view.
- Display files using grid or list layouts.
- Sort files by name, modification date or size.
- Create new files and directories.
- Rename files and directories.
- Copy, cut and paste multiple selected items.
- Move files to the Trash.
- Drag and drop files between directories and different apps.
- Create a new folder containing the selected files.
- Show or hide hidden files.
- Undo and redo supported file operations.

Developer tools

- Open the current directory in Terminal / VSCode.
- Copy regular filesystem paths.
- Copy shell-escaped paths.
- Compress selected files and directories into archives.
- Open files using a manually selected application.
- Reveal selected items in Finder.
- Git operations such as staging, branch switching and comitting directly from app's internal UI.

Native macOS experience

- SwiftUI-based interface using NavigationSplitView.
- Native AppKit file operations and system pasteboard integration.
- Standard macOS keyboard commands for copying, cutting and pasting.
- Command-click and Shift-click multi-selection.
- Selection rectangle support.
- Native drag-and-drop interactions.
- Native in-app tabs support
- System thumbnails and file metadata.
- Integrated sound effects.
- Native support for Apple silicon and Intel Macs.

---

## Screenshots

<img width="1059" height="672" alt="Preview1" src="https://github.com/user-attachments/assets/227a3e36-d2bc-4c49-bdaf-222f8cbeeef6" />
<img width="1059" height="701" alt="Preview2" src="https://github.com/user-attachments/assets/f76f5b21-0b5b-46a9-89d5-e11efa689727" />
<img width="1059" height="672" alt="Preview3" src="https://github.com/user-attachments/assets/4bc9b94d-741f-4950-a0c6-514a5101d810" />
<img width="1059" height="672" alt="Preview4" src="https://github.com/user-attachments/assets/fcc5954c-b4a6-44c8-a715-c2e84e2167b6" />

---

### Project Index (Temp)

<details open>
	<summary><b><code>RIVERFLOW/</code></b></summary>
	<details>
		<summary><b>__root__</b></summary>
		<blockquote>
			<div class='directory-path' style='padding: 8px 0; color: #666;'>
				<code><b>⦿ __root__</b></code>
			<table style='width: 100%; border-collapse: collapse;'>
			<thead>
				<tr style='background-color: #f8f9fa;'>
					<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
					<th style='text-align: left; padding: 8px;'>Summary</th>
				</tr>
			</thead>
				<tr style='border-bottom: 1px solid #eee;'>
					<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/LICENSE'>LICENSE</a></b></td>
					<td style='padding: 8px;'>Contains informations about source code licensing including usage and contributing</code></td>
				</tr>
				<tr style='border-bottom: 1px solid #eee;'>
					<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/README.md'>README.md</a></b></td>
					<td style='padding: 8px;'>Contains essential data about project and repository</code></td>
				</tr>
				<tr style='border-bottom: 1px solid #eee;'>
					<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/EULA.md'>EULA.md</a></b></td>
					<td style='padding: 8px;'>Contains informations about official binaries licensing</code></td>
				</tr>
			</table>
		</blockquote>
	</details>
	<details>
		<summary><b>RiverFlowTests</b></summary>
		<blockquote>
			<div class='directory-path' style='padding: 8px 0; color: #666;'>
				<code><b>⦿ RiverFlowTests</b></code>
			<table style='width: 100%; border-collapse: collapse;'>
			<thead>
				<tr style='background-color: #f8f9fa;'>
					<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
					<th style='text-align: left; padding: 8px;'>Summary</th>
				</tr>
			</thead>
				<tr style='border-bottom: 1px solid #eee;'>
					<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlowTests/RiverFlowTests.swift'>RiverFlowTests.swift</a></b></td>
					<td style='padding: 8px;'>Contains project's all Swift Testing unit tests</code></td>
				</tr>
			</table>
		</blockquote>
	</details>
	<details>
		<summary><b>RiverFlowUITests</b></summary>
		<blockquote>
			<div class='directory-path' style='padding: 8px 0; color: #666;'>
				<code><b>⦿ RiverFlowUITests</b></code>
			<table style='width: 100%; border-collapse: collapse;'>
			<thead>
				<tr style='background-color: #f8f9fa;'>
					<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
					<th style='text-align: left; padding: 8px;'>Summary</th>
				</tr>
			</thead>
				<tr style='border-bottom: 1px solid #eee;'>
					<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlowUITests/RiverFlowUITests.swift'>RiverFlowUITests.swift</a></b></td>
					<td style='padding: 8px;'></code></td>
				</tr>
				<tr style='border-bottom: 1px solid #eee;'>
					<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlowUITests/RiverFlowUITestsLaunchTests.swift'>RiverFlowUITestsLaunchTests.swift</a></b></td>
					<td style='padding: 8px;'></code></td>
				</tr>
			</table>
		</blockquote>
	</details>
	<details>
		<summary><b>RiverFlow</b></summary>
		<blockquote>
			<div class='directory-path' style='padding: 8px 0; color: #666;'>
				<code><b>⦿ RiverFlow</b></code>
			<table style='width: 100%; border-collapse: collapse;'>
			<thead>
				<tr style='background-color: #f8f9fa;'>
					<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
					<th style='text-align: left; padding: 8px;'>Summary</th>
				</tr>
			</thead>
				<tr style='border-bottom: 1px solid #eee;'>
					<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/RiverFlow.entitlements'>RiverFlow.entitlements</a></b></td>
					<td style='padding: 8px;'>[]</code></td>
				</tr>
			</table>
			<details>
				<summary><b>Models</b></summary>
				<blockquote>
					<div class='directory-path' style='padding: 8px 0; color: #666;'>
						<code><b>⦿ RiverFlow.Models</b></code>
					<table style='width: 100%; border-collapse: collapse;'>
					<thead>
						<tr style='background-color: #f8f9fa;'>
							<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
							<th style='text-align: left; padding: 8px;'>Summary</th>
						</tr>
					</thead>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Models/Enums.swift'>Enums.swift</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Models/FileItem.swift'>FileItem.swift</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Models/SidebarNode.swift'>SidebarNode.swift</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
					</table>
				</blockquote>
			</details>
			<details>
				<summary><b>Services</b></summary>
				<blockquote>
					<div class='directory-path' style='padding: 8px 0; color: #666;'>
						<code><b>⦿ RiverFlow.Services</b></code>
					<table style='width: 100%; border-collapse: collapse;'>
					<thead>
						<tr style='background-color: #f8f9fa;'>
							<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
							<th style='text-align: left; padding: 8px;'>Summary</th>
						</tr>
					</thead>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Services/FileWindowManager.swift'>FileWindowManager.swift</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Services/SoundEffects.swift'>SoundEffects.swift</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Services/ThumbnailManager.swift'>ThumbnailManager.swift</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
					</table>
				</blockquote>
			</details>
			<details>
				<summary><b>Sounds</b></summary>
				<blockquote>
					<div class='directory-path' style='padding: 8px 0; color: #666;'>
						<code><b>⦿ RiverFlow.Sounds</b></code>
					<table style='width: 100%; border-collapse: collapse;'>
					<thead>
						<tr style='background-color: #f8f9fa;'>
							<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
							<th style='text-align: left; padding: 8px;'>Summary</th>
						</tr>
					</thead>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Sounds/riverflow.aiff'>riverflow.aiff</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Sounds/confirmation.aiff'>confirmation.aiff</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Sounds/trash.aiff'>trash.aiff</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Sounds/error.aif'>error.aif</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
					</table>
				</blockquote>
			</details>
			<details>
				<summary><b>ViewModels</b></summary>
				<blockquote>
					<div class='directory-path' style='padding: 8px 0; color: #666;'>
						<code><b>⦿ RiverFlow.ViewModels</b></code>
					<table style='width: 100%; border-collapse: collapse;'>
					<thead>
						<tr style='background-color: #f8f9fa;'>
							<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
							<th style='text-align: left; padding: 8px;'>Summary</th>
						</tr>
					</thead>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/ViewModels/FolderViewModel.swift'>FolderViewModel.swift</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
					</table>
				</blockquote>
			</details>
			<details>
				<summary><b>Assets.xcassets</b></summary>
				<blockquote>
					<div class='directory-path' style='padding: 8px 0; color: #666;'>
						<code><b>⦿ RiverFlow.Assets.xcassets</b></code>
					<table style='width: 100%; border-collapse: collapse;'>
					<thead>
						<tr style='background-color: #f8f9fa;'>
							<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
							<th style='text-align: left; padding: 8px;'>Summary</th>
						</tr>
					</thead>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Assets.xcassets/Contents.json'>Contents.json</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
					</table>
					<details>
						<summary><b>AppLogo.imageset</b></summary>
						<blockquote>
							<div class='directory-path' style='padding: 8px 0; color: #666;'>
								<code><b>⦿ RiverFlow.Assets.xcassets.AppLogo.imageset</b></code>
							<table style='width: 100%; border-collapse: collapse;'>
							<thead>
								<tr style='background-color: #f8f9fa;'>
									<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
									<th style='text-align: left; padding: 8px;'>Summary</th>
								</tr>
							</thead>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Assets.xcassets/AppLogo.imageset/Contents.json'>Contents.json</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
							</table>
						</blockquote>
					</details>
					<details>
						<summary><b>AccentColor.colorset</b></summary>
						<blockquote>
							<div class='directory-path' style='padding: 8px 0; color: #666;'>
								<code><b>⦿ RiverFlow.Assets.xcassets.AccentColor.colorset</b></code>
							<table style='width: 100%; border-collapse: collapse;'>
							<thead>
								<tr style='background-color: #f8f9fa;'>
									<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
									<th style='text-align: left; padding: 8px;'>Summary</th>
								</tr>
							</thead>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Assets.xcassets/AccentColor.colorset/Contents.json'>Contents.json</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
							</table>
						</blockquote>
					</details>
					<details>
						<summary><b>AppIcon.appiconset</b></summary>
						<blockquote>
							<div class='directory-path' style='padding: 8px 0; color: #666;'>
								<code><b>⦿ RiverFlow.Assets.xcassets.AppIcon.appiconset</b></code>
							<table style='width: 100%; border-collapse: collapse;'>
							<thead>
								<tr style='background-color: #f8f9fa;'>
									<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
									<th style='text-align: left; padding: 8px;'>Summary</th>
								</tr>
							</thead>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Assets.xcassets/AppIcon.appiconset/Contents.json'>Contents.json</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
							</table>
						</blockquote>
					</details>
				</blockquote>
			</details>
			<details>
				<summary><b>App</b></summary>
				<blockquote>
					<div class='directory-path' style='padding: 8px 0; color: #666;'>
						<code><b>⦿ RiverFlow.App</b></code>
					<table style='width: 100%; border-collapse: collapse;'>
					<thead>
						<tr style='background-color: #f8f9fa;'>
							<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
							<th style='text-align: left; padding: 8px;'>Summary</th>
						</tr>
					</thead>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/App/SplashView.swift'>SplashView.swift</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/App/RiverFlowApp.swift'>RiverFlowApp.swift</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
					</table>
				</blockquote>
			</details>
			<details>
				<summary><b>Views</b></summary>
				<blockquote>
					<div class='directory-path' style='padding: 8px 0; color: #666;'>
						<code><b>⦿ RiverFlow.Views</b></code>
					<table style='width: 100%; border-collapse: collapse;'>
					<thead>
						<tr style='background-color: #f8f9fa;'>
							<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
							<th style='text-align: left; padding: 8px;'>Summary</th>
						</tr>
					</thead>
						<tr style='border-bottom: 1px solid #eee;'>
							<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/ContentView.swift'>ContentView.swift</a></b></td>
							<td style='padding: 8px;'>[]</code></td>
						</tr>
					</table>
					<details>
						<summary><b>Components</b></summary>
						<blockquote>
							<div class='directory-path' style='padding: 8px 0; color: #666;'>
								<code><b>⦿ RiverFlow.Views.Components</b></code>
							<table style='width: 100%; border-collapse: collapse;'>
							<thead>
								<tr style='background-color: #f8f9fa;'>
									<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
									<th style='text-align: left; padding: 8px;'>Summary</th>
								</tr>
							</thead>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/Components/GitBadgeView.swift'>GitBadgeView.swift</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/Components/FileInfoView.swift'>FileInfoView.swift</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/Components/SidebarView.swift'>SidebarView.swift</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/Components/FileGridItemView.swift'>FileGridItemView.swift</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/Components/InteractivePathTitleView.swift'>InteractivePathTitleView.swift</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/Components/FileIconView.swift'>FileIconView.swift</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/Components/FileListItemView.swift'>FileListItemView.swift</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/Components/RightClickCatcher.swift'>RightClickCatcher.swift</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/Components/EditableFileNameView.swift'>EditableFileNameView.swift</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
							</table>
						</blockquote>
					</details>
					<details>
						<summary><b>ContextMenus</b></summary>
						<blockquote>
							<div class='directory-path' style='padding: 8px 0; color: #666;'>
								<code><b>⦿ RiverFlow.Views.ContextMenus</b></code>
							<table style='width: 100%; border-collapse: collapse;'>
							<thead>
								<tr style='background-color: #f8f9fa;'>
									<th style='width: 30%; text-align: left; padding: 8px;'>File Name</th>
									<th style='text-align: left; padding: 8px;'>Summary</th>
								</tr>
							</thead>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/ContextMenus/FileContextMenu.swift'>FileContextMenu.swift</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
								<tr style='border-bottom: 1px solid #eee;'>
									<td style='padding: 8px;'><b><a href='https://github.com/Predsu/RiverFlow/blob/master/RiverFlow/Views/ContextMenus/FolderContextMenu.swift'>FolderContextMenu.swift</a></b></td>
									<td style='padding: 8px;'>[]</code></td>
								</tr>
							</table>
						</blockquote>
					</details>
				</blockquote>
			</details>
		</blockquote>
	</details>
</details>

---

## Privacy

RiverFlow is designed as a local desktop application.

- File browsing and management happen directly on the Mac.
- File contents are not uploaded to an external service by RiverFlow.
- The application does not require an account or cloud connection.

As with any file manager, RiverFlow needs access to the directories and files you choose to manage. macOS may request additional permissions for protected locations.

---

## Installation & First Launch

Reviewers and users **do not need to compile demo of this project from source**. Follow these steps to get the app demo running in seconds:

1. Go to the [Releases Page](https://github.com/Predsu/RiverFlow/releases/latest) and download the lastest `RiverFlowDemo.dmg` file.
2. Double-click the downloaded `.dmg` file and drag **RiverFlow** into your **Applications** folder.
3. Open your Applications folder and launch the app.

App demo is only Official Binary type that is available without any payments, it is a version meant to showcase the app's possibilities to any person reviewing or considering the purchase. It will be updated ocassionally, mostly before major updates but it's current state DOES NOT necessarily reflect the current state of the app's full version.

**Current full version**: none<br>
**Current demo version**: none<br>
**Is demo based on last release**: *NO*<br>
**Last version the demo is based on**: none

### Overriding macOS Gatekeeper (Fixing the "Developer Cannot Be Verified" Error)

Because this app is an open-source project and is not (yet) distributed through the Mac App Store, macOS Gatekeeper might block the first launch with a warning. To safely bypass this:

1. Try to open the app normally. You'll get the warning about security.
2. Open System Settings → Privacy & Security.
3. Scroll to the bottom. You'll see a message that the app was blocked. Click Open Anyway.
4. Enter your password or use Touch ID.
5. Confirm Open.
6. The app will now launch successfully.

---

## Contributing

<details closed>
<summary>Contributing Guidelines</summary>

Contributing guidelines are under construction.

</details>

<details closed>
<summary>Contributor Graph</summary>
<br>
<p align="left">
   <a href="https://github.com{/Predsu/RiverFlow/}graphs/contributors">
      <img src="https://contrib.rocks/image?repo=Predsu/RiverFlow">
   </a>
</p>
</details>

---

## License

Riverflow source code is protected under the [RKNCSL LICENSE](https://raw.githubusercontent.com/Predsu/RiverFlow/main/LICENSE) License.<br>
All distributed binaries are protected under the [EULA](https://raw.githubusercontent.com/Predsu/RiverFlow/main/EULA.md)

---

## About AI usage

AI has not took part in planning the development of the app, every feature has been designed by me. Development is AI-assisted (pair-programming, code review) but it never writes full features or does automatic shipping. 

---

## Acknowledgements

RiverFlow is part of **The Shrimple Project**, a set of lightweight, native QoL macOS apps. More about the project [here](https://toriyukari.neocities.org/tsc)
