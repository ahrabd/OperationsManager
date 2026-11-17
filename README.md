# Operations Manager

### A Lightweight Interactive Terminal File Manager & Operations Suite for Windows

Operations Manager is a lightweight, self-contained terminal-based file manager designed for Windows. Built with Windows Batch, embedded PowerShell, and inline C# using the Win32 Console API, it provides an interactive text-based user interface (TUI) for browsing directories and managing files directly from the Windows console.

With keyboard and mouse navigation, file and folder operations, an integrated properties inspector, and a command shell launcher, Operations Manager brings essential file management capabilities into a single executable `.bat` file.

---

## Features

### Interactive Terminal User Interface
- Responsive, console-based text user interface.
- Keyboard and mouse navigation.
- Highlighted selections and interactive context menus.
- Dynamic screen rendering and resizing support.
- Scrollable directory listings.

### File & Directory Management
- Browse local directories and drives.
- Navigate between parent and child directories.
- Open files using their associated Windows applications.
- Create new files and folders.
- Copy files and directories.
- Move files and directories.
- Rename files and folders.
- Delete files and folders recursively.

### Context-Aware Action Menu
Access file and folder operations through an interactive action menu.

Available actions include:
- Open / Run
- Copy / Move
- Rename
- Delete
- Properties / Info
- Create New File / Folder

### Properties Inspector
View detailed information about files and directories:

- File or folder name.
- Full filesystem path.
- File type.
- Exact file size in bytes.
- Creation timestamp.
- Last modification timestamp.
- File attributes.
- File owner information, when accessible.

### Integrated Command Shell
- Launch a new Windows Command Prompt (`cmd.exe`).
- Execute custom commands.
- Automatically use the currently selected working directory as the command shell's working directory.

### Protected Operations
- Password verification before copy/move and delete operations.
- Confirmation prompt before deletion.
- Cancellation support for sensitive operations.

**Note:** The password protection is a basic application-level safeguard, not a security boundary. The current source contains a hardcoded password. It should be changed before distribution, and it must not be relied upon to protect sensitive files.

---

## Technology Stack

| Technology | Purpose |
|---|---|
| Windows Batch (.bat) | Application launcher |
| PowerShell 5.1+ / 7+ | Application logic |
| Inline C# | Console API integration |
| Win32 Console API | Keyboard, mouse and screen handling |
| .NET Framework / .NET | Runtime support |

---

## Requirements

- Windows operating system.
- Windows PowerShell 5.1 or PowerShell 7+.
- Windows console environment with Win32 Console API support.
- Permission to execute PowerShell scripts and perform the requested filesystem operations.

No additional third-party dependencies are required.

---

## Installation & Usage

### Option 1: Download

1. Open the [OperationsManager GitHub repository](https://github.com/ahrabd/OperationsManager).
2. Download or clone the repository.
3. Locate `operationsmanager.bat`.
4. Run the batch file.

### Option 2: Clone Using Git

```bash
git clone https://github.com/ahrabd/OperationsManager.git
cd OperationsManager
```

### Launch

Run the application from Command Prompt or PowerShell:

```cmd
operationsmanager.bat
```

You can also double-click `operationsmanager.bat` in Windows Explorer.

The application extracts its embedded PowerShell engine into a temporary script, launches the interactive console interface, and removes the temporary script after execution.

---

## Keyboard Shortcuts

| Key | Action |
|---|---|
| Up Arrow | Navigate up |
| Down Arrow | Navigate down |
| Enter | Open selected item |
| Backspace | Navigate to parent directory |
| M | Open context actions menu |
| N | Create a new file or folder |
| C | Launch Command Prompt / custom command |
| Page Up | Move selection up by 10 items |
| Page Down | Move selection down by 10 items |
| Home | Select the first item |
| End | Select the last item |
| Esc | Close menus or exit application |

### Mouse Controls

| Action | Function |
|---|---|
| Mouse Click | Select or open an item |
| Mouse Hover | Highlight an item or menu option |
| Mouse Wheel | Scroll through directory listings |

---

## How It Works

Operations Manager uses a hybrid execution architecture:

1. The Batch launcher reads its own source file.
2. It extracts the embedded PowerShell code into a uniquely named temporary `.ps1` file.
3. PowerShell executes the application engine.
4. Inline C# is compiled using PowerShell's `Add-Type`.
5. The C# layer communicates with the Windows kernel32 Console API.
6. The application processes keyboard and mouse events and renders the interactive interface.
7. On exit, the application restores the console input settings and removes the temporary PowerShell script.

This architecture keeps the application self-contained in a single Batch file.

---

## Project Structure

```text
OperationsManager/
│
├── OperationsManager/
│   └── operationsmanager.bat
│
├── LICENSE
│
└── README.md
```

---

## Security Considerations

Operations Manager performs direct filesystem operations. Please keep the following points in mind:

- Copy, move, and delete operations require application-level password verification.
- Deletion includes a confirmation prompt.
- The current password is hardcoded in the source code and is not securely stored.
- The application inherits the permissions of the Windows user running it.
- Custom commands execute through Windows Command Prompt and can perform arbitrary actions permitted to that user.
- Always verify the selected path before performing destructive operations.
- Use caution when managing system directories or important files.

**Important:** This application does not elevate privileges automatically and does not provide operating-system-level access control.

---

## License

This project is licensed under the MIT License.

See the [LICENSE](LICENSE) file for details.

---

## Author

**ahrabd**

GitHub: [@ahrabd](https://github.com/ahrabd)

Project Repository: [OperationsManager](https://github.com/ahrabd/OperationsManager)

---

*Operations Manager — Simple, Interactive, and Efficient Windows File Management.*
