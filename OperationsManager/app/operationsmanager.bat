@echo off
setlocal DisableDelayedExpansion
:: operationsmanager.bat - Interactive Terminal File Manager & Operations Suite
:: Launch this script's embedded PowerShell TUI engine.
set "OM_PS1=%TEMP%\operationsmanager_%RANDOM%%RANDOM%.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=[IO.File]::ReadAllText('%~f0',[Text.Encoding]::UTF8);$m=[string][char]13+[char]10+'#POWERSHELL';$i=$c.LastIndexOf($m);if($i -lt 0){$i=$c.LastIndexOf([char]10+'#POWERSHELL')};if($i -lt 0){Write-Error 'Embedded script not found.';exit 1};$i++;[IO.File]::WriteAllText('%OM_PS1%',$c.Substring($i),[Text.Encoding]::UTF8)"
if errorlevel 1 (endlocal & exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%OM_PS1%"
set "OM_EC=%ERRORLEVEL%"
del "%OM_PS1%" >nul 2>&1
endlocal & exit /b %OM_EC%

#POWERSHELL
# Operations Manager TUI (PowerShell + inline C#)
# Requires Windows PowerShell 5.1+ or PowerShell 7+ on Windows with console APIs.

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = 'Operations Manager'

if (-not ('OM.ConsoleApi' -as [type])) {
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace OM {
    [StructLayout(LayoutKind.Sequential)] public struct COORD { public short X; public short Y; }
    [StructLayout(LayoutKind.Sequential)] public struct SMALL_RECT { public short Left; public short Top; public short Right; public short Bottom; }

    [StructLayout(LayoutKind.Explicit, CharSet=CharSet.Unicode)]
    public struct CHAR_INFO {
        [FieldOffset(0)] public char UnicodeChar;
        [FieldOffset(2)] public short Attributes;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct CONSOLE_SCREEN_BUFFER_INFO {
        public COORD dwSize;
        public COORD dwCursorPosition;
        public short wAttributes;
        public SMALL_RECT srWindow;
        public COORD dwMaximumWindowSize;
    }

    [StructLayout(LayoutKind.Sequential)] public struct FOCUS_EVENT_RECORD { public uint bSetFocus; }
    [StructLayout(LayoutKind.Sequential)] public struct MENU_EVENT_RECORD { public uint dwCommandId; }

    [StructLayout(LayoutKind.Explicit)]
    public struct KEY_EVENT_RECORD {
        [FieldOffset(0)] public bool bKeyDown;
        [FieldOffset(4)] public ushort wRepeatCount;
        [FieldOffset(6)] public ushort wVirtualKeyCode;
        [FieldOffset(8)] public ushort wVirtualScanCode;
        [FieldOffset(10)] public char UnicodeChar;
        [FieldOffset(12)] public uint dwControlKeyState;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct MOUSE_EVENT_RECORD {
        [FieldOffset(0)] public COORD dwMousePosition;
        [FieldOffset(4)] public uint dwButtonState;
        [FieldOffset(8)] public uint dwControlKeyState;
        [FieldOffset(12)] public uint dwEventFlags;
    }

    [StructLayout(LayoutKind.Sequential)] public struct WINDOW_BUFFER_SIZE_RECORD { public COORD dwSize; }

    [StructLayout(LayoutKind.Explicit)]
    public struct INPUT_RECORD {
        [FieldOffset(0)] public ushort EventType;
        [FieldOffset(4)] public KEY_EVENT_RECORD KeyEvent;
        [FieldOffset(4)] public MOUSE_EVENT_RECORD MouseEvent;
        [FieldOffset(4)] public WINDOW_BUFFER_SIZE_RECORD WindowBufferSizeEvent;
        [FieldOffset(4)] public MENU_EVENT_RECORD MenuEvent;
        [FieldOffset(4)] public FOCUS_EVENT_RECORD FocusEvent;
    }

    public static class ConsoleApi {
        public const int STD_INPUT_HANDLE = -10;
        public const int STD_OUTPUT_HANDLE = -11;
        public const uint ENABLE_EXTENDED_FLAGS = 0x0080;
        public const uint ENABLE_WINDOW_INPUT = 0x0008;
        public const uint ENABLE_MOUSE_INPUT = 0x0010;
        public const uint ENABLE_QUICK_EDIT_MODE = 0x0040;
        public const ushort KEY_EVENT = 0x0001;
        public const ushort MOUSE_EVENT = 0x0002;
        public const ushort WINDOW_BUFFER_SIZE_EVENT = 0x0004;
        public const uint FROM_LEFT_1ST_BUTTON_PRESSED = 0x0001;
        public const uint MOUSE_MOVED = 0x0001;
        public const uint MOUSE_WHEELED = 0x0004;

        [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool ReadConsoleInput(IntPtr hConsoleInput, [Out] INPUT_RECORD[] lpBuffer, uint nLength, out uint lpNumberOfEventsRead);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool WriteConsoleOutputCharacter(IntPtr hConsoleOutput, StringBuilder lpCharacter, uint nLength, COORD dwWriteCoord, out uint lpNumberOfCharsWritten);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern bool WriteConsoleOutputAttribute(IntPtr hConsoleOutput, short[] lpAttribute, uint nLength, COORD dwWriteCoord, out uint lpNumberOfAttrsWritten);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleScreenBufferInfo(IntPtr hConsoleOutput, out CONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleCursorPosition(IntPtr hConsoleOutput, COORD dwCursorPosition);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern bool FillConsoleOutputCharacter(IntPtr hConsoleOutput, char cCharacter, uint nLength, COORD dwWriteCoord, out uint lpNumberOfCharsWritten);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern bool FillConsoleOutputAttribute(IntPtr hConsoleOutput, short wAttribute, uint nLength, COORD dwWriteCoord, out uint lpNumberOfAttrsWritten);

        public static short MakeAttr(int fg, int bg, bool bright) {
            int f = fg & 0x7;
            int b = bg & 0x7;
            int a = f | (b << 4);
            if (bright) a |= 0x08;
            return (short)a;
        }
    }
}
"@
}

$script:hIn  = [OM.ConsoleApi]::GetStdHandle([OM.ConsoleApi]::STD_INPUT_HANDLE)
$script:hOut = [OM.ConsoleApi]::GetStdHandle([OM.ConsoleApi]::STD_OUTPUT_HANDLE)
$script:origInMode = 0
$script:origOutMode = 0
[void][OM.ConsoleApi]::GetConsoleMode($script:hIn, [ref]$script:origInMode)
try { [void][OM.ConsoleApi]::GetConsoleMode($script:hOut, [ref]$script:origOutMode) } catch {}
$newMode = ([OM.ConsoleApi]::ENABLE_EXTENDED_FLAGS -bor [OM.ConsoleApi]::ENABLE_WINDOW_INPUT -bor [OM.ConsoleApi]::ENABLE_MOUSE_INPUT)
# Clear quick-edit flag explicitly
$newMode = $newMode -band (-bnot [OM.ConsoleApi]::ENABLE_QUICK_EDIT_MODE)
[void][OM.ConsoleApi]::SetConsoleMode($script:hIn, $newMode)

function Get-BufferSize {
    $info = New-Object OM.CONSOLE_SCREEN_BUFFER_INFO
    [void][OM.ConsoleApi]::GetConsoleScreenBufferInfo($script:hOut, [ref]$info)
    return @{ Width = [int]$info.dwSize.X; Height = [int]$info.srWindow.Bottom - [int]$info.srWindow.Top + 1; Top = [int]$info.srWindow.Top }
}

function Clear-ScreenBuffer {
    $sz = Get-BufferSize
    $coord = New-Object OM.COORD
    $coord.X = 0; $coord.Y = [int16]$sz.Top
    $cells = [System.UInt32]($sz.Width * $sz.Height) 
    $w = 0
    [void][OM.ConsoleApi]::FillConsoleOutputCharacter($script:hOut, [char]' ', $cells, $coord, [ref]$w)
    [void][OM.ConsoleApi]::FillConsoleOutputAttribute($script:hOut, [int16]0x07, $cells, $coord, [ref]$w)
    [void][OM.ConsoleApi]::SetConsoleCursorPosition($script:hOut, $coord)
}

function Write-LineAt([int]$x, [int]$y, [string]$text, [int]$attr) {
    $sz = Get-BufferSize
    if ($y -lt 0 -or $y -ge $sz.Height) { return }
    $absY = $sz.Top + $y
    $max = [Math]::Max(0, $sz.Width - $x)
    if ($max -le 0) { return }
    $t = $text
    if ($t.Length -gt $max) { $t = $t.Substring(0, $max) }
    else { $t = $t + (' ' * ($max - $t.Length)) }
    $coord = New-Object OM.COORD
    $coord.X = [int16]$x; $coord.Y = [int16]$absY
    $sb = New-Object System.Text.StringBuilder $t
    $w = 0
    [void][OM.ConsoleApi]::WriteConsoleOutputCharacter($script:hOut, $sb, [System.UInt32]$t.Length, $coord, [ref]$w)
    $attrs = New-Object int16[] $t.Length
    for ($i=0; $i -lt $attrs.Length; $i++) { $attrs[$i] = [int16]$attr }
    [void][OM.ConsoleApi]::WriteConsoleOutputAttribute($script:hOut, $attrs, [System.UInt32]$t.Length, $coord, [ref]$w)
}

function Format-Size([long]$bytes) {
    if ($bytes -ge 1GB) { return '{0:N1} GB' -f ($bytes/1GB) }
    if ($bytes -ge 1MB) { return '{0:N1} MB' -f ($bytes/1MB) }
    if ($bytes -ge 1KB) { return '{0:N1} KB' -f ($bytes/1KB) }
    return "$bytes B"
}

function Get-ParentPath([string]$path) {
    $root = [IO.Path]::GetPathRoot($path)
    $parent = $null
    try { $di = [IO.Directory]::GetParent($path); if ($di) { $parent = $di.FullName } } catch {}
    if (-not $parent -or $parent -eq $path) {
        if ($root -and $path -ne $root) { return $root }
        return $null
    }
    return $parent
}

function Get-DirectoryItems([string]$path) {
    $items = @()
    $parent = Get-ParentPath $path
    $upTarget = $null
    if ($parent -and $parent -ne $path) { $upTarget = $parent }
    elseif ($path -ne $root -and $root) { $upTarget = $root }
    if ($upTarget) { $items += [pscustomobject]@{ Name='..'; FullName=$upTarget; IsDir=$true; IsUp=$true; Size=''; Modified=$null } }
    try {
        $dirs = Get-ChildItem -LiteralPath $path -Force -ErrorAction Stop | Where-Object { $_.PSIsContainer } | Sort-Object Name
        foreach ($d in $dirs) { $items += [pscustomobject]@{ Name=$d.Name; FullName=$d.FullName; IsDir=$true; IsUp=$false; Size='<DIR>'; Modified=$d.LastWriteTime } }
        $files = Get-ChildItem -LiteralPath $path -Force -ErrorAction Stop | Where-Object { -not $_.PSIsContainer } | Sort-Object Name
        foreach ($f in $files) { $items += [pscustomobject]@{ Name=$f.Name; FullName=$f.FullName; IsDir=$false; IsUp=$false; Size=(Format-Size $f.Length); Modified=$f.LastWriteTime; Length=$f.Length } }
    } catch {
        $script:statusMsg = "Error reading directory: $($_.Exception.Message)"
    }
    return ,$items
}

$script:currentPath = (Get-Location).ProviderPath
$script:items = @()
$script:selected = 0
$script:scroll = 0
$script:statusMsg = 'Ready. Arrows/Mouse navigate, Enter=open, M=actions, Backspace=up, N=new, C=command, Esc=exit.'
$script:mode = 'browse' # browse | menu | input | confirm | info
$script:menuIndex = 0
$script:menuButtons = @()
$script:menuItem = $null
$script:inputPrompt = ''
$script:inputText = ''
$script:inputAction = $null
$script:confirmPrompt = ''
$script:confirmButtons = @('Yes','No')
$script:confirmIndex = 1
$script:confirmAction = $null
$script:infoLines = @()
$script:actionItem = $null
$script:pendingPasswordAction = $null

function Refresh-Items {
    $script:items = Get-DirectoryItems $script:currentPath
    if ($script:selected -ge $script:items.Count) { $script:selected = [Math]::Max(0, $script:items.Count - 1) }
    if ($script:selected -lt 0) { $script:selected = 0 }
}

function Clamp-Scroll([int]$listHeight) {
    if ($script:selected -lt $script:scroll) { $script:scroll = $script:selected }
    if ($script:selected -ge ($script:scroll + $listHeight)) { $script:scroll = $script:selected - $listHeight + 1 }
    if ($script:scroll -lt 0) { $script:scroll = 0 }
    $maxScroll = [Math]::Max(0, $script:items.Count - $listHeight)
    if ($script:scroll -gt $maxScroll) { $script:scroll = $maxScroll }
}

function Open-SelectedItem {
    if ($script:items.Count -eq 0) { return }
    $it = $script:items[$script:selected]
    if ($it.IsDir) {
        try {
            $script:currentPath = (Resolve-Path -LiteralPath $it.FullName).ProviderPath
            $script:selected = 0; $script:scroll = 0
            $script:statusMsg = 'Opened folder.'
            Refresh-Items
        } catch { $script:statusMsg = "Cannot open folder: $($_.Exception.Message)" }
    } else {
        try { Start-Process -FilePath $it.FullName; $script:statusMsg = "Launched: $($it.Name)" }
        catch { $script:statusMsg = "Cannot open file: $($_.Exception.Message)" }
    }
}

$script:safeModePassword = 'abc123'

function Show-ActionMenu($item) {
    $script:mode = 'menu'
    $script:menuItem = $item
    $script:menuIndex = 0
    if ($item.IsUp) { $script:menuButtons = @('Open') }
    elseif ($item.IsDir) { $script:menuButtons = @('Open','Copy / Move','Rename','Delete','Properties / Info','Create New File / Folder','Cancel') }
    else { $script:menuButtons = @('Open / Run','Copy / Move','Rename','Delete','Properties / Info','Create New File / Folder','Cancel') }
}

function Require-Password([string]$reason, [scriptblock]$onSuccess) {
    $script:pendingPasswordAction = $onSuccess
    Begin-Input ("Enter password to $reason" + ': ') '' {
        param($pw)
        if ($pw -ceq $script:safeModePassword) {
            $cb = $script:pendingPasswordAction
            $script:pendingPasswordAction = $null
            if ($cb) { & $cb }
        } else {
            $script:pendingPasswordAction = $null
            $script:mode = 'browse'
            $script:statusMsg = 'Incorrect password. Action cancelled.'
        }
    }
}

function Begin-Input([string]$prompt, [string]$default, [scriptblock]$action) {
    $script:mode = 'input'
    $script:inputPrompt = $prompt
    $script:inputText = $default
    $script:inputAction = $action
}

function Begin-Confirm([string]$prompt, [scriptblock]$action) {
    $script:mode = 'confirm'
    $script:confirmPrompt = $prompt
    $script:confirmIndex = 1
    $script:confirmAction = $action
}

function Show-Info($item) {
    $lines = @()
    $lines += "Name: $($item.Name)"
    $lines += "Path: $($item.FullName)"
    try {
        $fi = Get-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
        $type = if ($fi.PSIsContainer) { 'Directory' } else { 'File' }
        $lines += "Type: $type"
        if (-not $fi.PSIsContainer) { $lines += "Size: $(Format-Size $fi.Length) ($($fi.Length) bytes)" }
        $lines += "Created: $($fi.CreationTime)"
        $lines += "Modified: $($fi.LastWriteTime)"
        $lines += "Attributes: $($fi.Attributes)"
        try { $acl = Get-Acl -LiteralPath $item.FullName; $lines += "Owner: $($acl.Owner)" } catch {}
    } catch { $lines += "Error: $($_.Exception.Message)" }
    $script:infoLines = $lines
    $script:mode = 'info'
}

function Do-CreateNew {
    Begin-Input 'Create: f=name (file) or d=name (folder), Enter to confirm' '' {
        param($txt)
        $txt = [string]$txt
        $txt = $txt.Trim()
        if (-not $txt) { $script:statusMsg = 'Create cancelled.'; $script:mode='browse'; return }
        $kind = 'f'; $name = $txt
        if ($txt -match '^(?i)([fd])\s*[:=]\s*(.+)$') { $kind = $matches[1].ToLower(); $name = $matches[2].Trim() }
        elseif ($txt -match '^(?i)(file|folder|dir)\s+(.+)$') { $kind = if ($matches[1].ToLower() -eq 'file'){'f'}else{'d'}; $name=$matches[2].Trim() }
        if (-not $name) { $script:statusMsg = 'Create cancelled (no name).'; $script:mode='browse'; return }
        $target = Join-Path $script:currentPath $name
        try {
            if ($kind -eq 'd') {
                if ([System.IO.Directory]::Exists($target) -or [System.IO.File]::Exists($target)) { $script:statusMsg = "Already exists: $name" }
                else { [void][System.IO.Directory]::CreateDirectory($target); $script:statusMsg = "Folder created: $name" }
            } else {
                if ([System.IO.File]::Exists($target) -or [System.IO.Directory]::Exists($target)) { $script:statusMsg = "Already exists: $name" }
                else {
                    $fs = [System.IO.File]::Create($target)
                    $fs.Close()
                    $fs.Dispose()
                    $script:statusMsg = "File created: $name"
                }
            }
            Refresh-Items
        } catch { $script:statusMsg = "Create failed: $($_.Exception.Message)" }
        $script:mode = 'browse'
    }
}

function Do-CustomCommand {
    Begin-Input 'Command (runs in cmd here, empty opens shell): ' '' {
        param($cmdText)
        $script:mode = 'browse'
        try {
            if ($cmdText -and $cmdText.Trim().Length -gt 0) {
                Start-Process -FilePath 'cmd.exe' -ArgumentList @('/k', $cmdText) -WorkingDirectory $script:currentPath
                $script:statusMsg = 'Launched command in new cmd window.'
            } else {
                Start-Process -FilePath 'cmd.exe' -WorkingDirectory $script:currentPath
                $script:statusMsg = 'Opened cmd in current directory.'
            }
        } catch {
            $script:statusMsg = "Command launch failed: $($_.Exception.Message)"
        }
    }
}

function Invoke-MenuAction([string]$action) {
    $item = $script:menuItem
    switch -Regex ($action) {
        '^(Open|Open / Run)$' { $script:mode='browse'; $script:selected = [Array]::IndexOf($script:items, $item); if ($script:selected -lt 0){$script:selected=0}; Open-SelectedItem; return }
        '^Copy / Move$' {
            $script:actionItem = $item
            Require-Password 'copy/move (paste)' {
                Begin-Input 'Destination path (prefix m: to move, default copy): ' '' {
                    param($dest)
                    $it = $script:actionItem
                    $script:mode='browse'
                    if (-not $dest) { $script:statusMsg='Cancelled.'; return }
                    $move = $false
                    if ($dest -match '^(?i)m:\s*(.+)$') { $move=$true; $dest=$matches[1].Trim() }
                    try {
                        $d = $dest
                        if (Test-Path -LiteralPath $d -PathType Container) { $d = Join-Path $d ([IO.Path]::GetFileName($it.FullName)) }
                        if ($move) { Move-Item -LiteralPath $it.FullName -Destination $d -Force -ErrorAction Stop; $script:statusMsg="Moved to $d" }
                        else { Copy-Item -LiteralPath $it.FullName -Destination $d -Recurse -Force -ErrorAction Stop; $script:statusMsg="Copied to $d" }
                        Refresh-Items
                    } catch { $script:statusMsg = "Copy/Move failed: $($_.Exception.Message)" }
                }
            }; return
        }
        '^Rename$' {
            $script:actionItem = $item
            Begin-Input "New name for '$($item.Name)': " $item.Name {
                param($newName)
                $it = $script:actionItem
                $script:mode='browse'
                if (-not $newName -or $newName -eq $it.Name) { $script:statusMsg='Rename cancelled.'; return }
                try { Rename-Item -LiteralPath $it.FullName -NewName $newName -ErrorAction Stop; $script:statusMsg="Renamed to $newName"; Refresh-Items }
                catch { $script:statusMsg = "Rename failed: $($_.Exception.Message)" }
            }; return
        }
        '^Delete$' {
            $script:actionItem = $item
            Require-Password 'delete' {
                Begin-Confirm "Delete '$($script:actionItem.Name)'?" {
                    param($yes)
                    $it = $script:actionItem
                    $script:mode='browse'
                    if (-not $yes) { $script:statusMsg='Delete cancelled.'; return }
                    try { Remove-Item -LiteralPath $it.FullName -Recurse -Force -ErrorAction Stop; $script:statusMsg="Deleted: $($it.Name)"; Refresh-Items }
                    catch { $script:statusMsg = "Delete failed: $($_.Exception.Message)" }
                }
            }; return
        }
        '^Properties / Info$' { Show-Info $item; return }
        '^Create New File / Folder$' { $script:mode='browse'; Do-CreateNew; return }
        '^Cancel$' { $script:mode='browse'; $script:statusMsg='Menu closed.'; return }
    }
}

function Draw-UI {
    $sz = Get-BufferSize
    $w = $sz.Width; $h = $sz.Height
    $attrHeader = 0x1F  # white on blue
    $attrBar    = 0x70  # black on gray
    $attrNormal = 0x07
    $attrDir    = 0x0B  # bright cyan
    $attrSel    = 0xE0  # black on yellow
    $attrHover  = 0x2F  # white on green
    $attrStatus = 0x30  # black on cyan-ish
    $attrMenu   = 0x17  # white on blue
    $attrMenuSel= 0xE0

    # Header
    $hdr = " Operations Manager  |  $($script:currentPath)"
    Write-LineAt 0 0 $hdr $attrHeader
    $hint = " Arrows/Mouse: navigate  Enter: open  M: actions  Backspace: up  N: new  C: cmd  Esc: exit "
    if ($h -gt 1) { Write-LineAt 0 1 $hint $attrBar }

    # File list area
    $listTop = 2
    $footerH = 2
    $menuPaneW = 0
    if ($script:mode -in @('menu','confirm','input','info')) { $menuPaneW = [Math]::Min(44, [Math]::Max(28, [int]($w * 0.38))) }
    $listW = $w - $menuPaneW
    $listH = [Math]::Max(1, $h - $listTop - $footerH)
    Clamp-Scroll $listH

    # Column header
    $col = ' {0,-4} {1,-40} {2,12}' -f 'TYPE','NAME','SIZE'
    Write-LineAt 0 $listTop $col $attrBar

    $rowStart = $listTop + 1
    $visible = $listH - 1
    for ($i=0; $i -lt $visible; $i++) {
        $idx = $script:scroll + $i
        $y = $rowStart + $i
        if ($idx -lt $script:items.Count) {
            $it = $script:items[$idx]
            $type = if ($it.IsDir) { '[DIR]' } else { '     ' }
            $name = [string]$it.Name
            $maxName = [Math]::Max(10, $listW - 22)
            if ($name.Length -gt $maxName) { $name = $name.Substring(0, [Math]::Max(1,$maxName-1)) + '~' }
            $sizeStr = [string]$it.Size
            $line = ' ' + $type.PadRight(5) + $name.PadRight($maxName) + ' ' + $sizeStr.PadLeft(12)
            $a = $attrNormal
            if ($it.IsDir) { $a = $attrDir }
            if ($idx -eq $script:hoverIndex -and $idx -ne $script:selected) { $a = $attrHover }
            if ($idx -eq $script:selected) { $a = $attrSel }
            Write-LineAt 0 $y $line $a
        } else {
            Write-LineAt 0 $y '' $attrNormal
        }
    }

    # Right/bottom pane for menu/info/input/confirm
    $script:uiHitRegions = @()
    if ($menuPaneW -gt 0) {
        $px = $listW
        for ($yy = $listTop; $yy -lt ($h-$footerH); $yy++) {
            Write-LineAt $px $yy ('|' + (' ' * ($menuPaneW-1))) $attrMenu
        }
        $title = ' Actions '
        if ($script:mode -eq 'info') { $title = ' Properties / Info ' }
        elseif ($script:mode -eq 'confirm') { $title = ' Confirm ' }
        elseif ($script:mode -eq 'input') { $title = ' Input ' }
        Write-LineAt $px $listTop ("|" + $title.PadRight($menuPaneW-1)) $attrMenuSel
        $py = $listTop + 2
        if ($script:mode -eq 'menu') {
            $targetName = if ($script:menuItem) { $script:menuItem.Name } else { '' }
            if ($targetName.Length -gt ($menuPaneW-4)) { $targetName = $targetName.Substring(0,$menuPaneW-7)+'...' }
            Write-LineAt ($px+2) $py $targetName $attrMenu; $py += 2
            for ($bi=0; $bi -lt $script:menuButtons.Count; $bi++) {
                $label = "[ $($script:menuButtons[$bi]) ]"
                $a = if ($bi -eq $script:menuIndex -or $bi -eq $script:hoverMenuIndex) { $attrMenuSel } else { $attrMenu }
                Write-LineAt ($px+2) $py $label $a
                $script:uiHitRegions += [pscustomobject]@{ Kind='menu'; Index=$bi; X1=($px+2); X2=($px+2+$label.Length); Y=$py }
                $py += 2
            }
        } elseif ($script:mode -eq 'confirm') {
            $msg = $script:confirmPrompt
            $wrapW = $menuPaneW - 4
            while ($msg.Length -gt 0 -and $py -lt ($h-$footerH-2)) {
                $chunk = if ($msg.Length -gt $wrapW) { $msg.Substring(0,$wrapW) } else { $msg }
                Write-LineAt ($px+2) $py $chunk $attrMenu
                $msg = if ($msg.Length -gt $wrapW) { $msg.Substring($wrapW) } else { '' }
                $py++
            }
            $py++
            for ($bi=0; $bi -lt $script:confirmButtons.Count; $bi++) {
                $label = "[ $($script:confirmButtons[$bi]) ]"
                $a = if ($bi -eq $script:confirmIndex) { $attrMenuSel } else { $attrMenu }
                Write-LineAt ($px+2 + ($bi*10)) $py $label $a
                $script:uiHitRegions += [pscustomobject]@{ Kind='confirm'; Index=$bi; X1=($px+2+($bi*10)); X2=($px+2+($bi*10)+$label.Length); Y=$py }
            }
        } elseif ($script:mode -eq 'input') {
            $msg = $script:inputPrompt
            $wrapW = $menuPaneW - 4
            foreach ($chunk in ($msg -split "(.{1,$wrapW})" | Where-Object {$_})) { Write-LineAt ($px+2) $py $chunk $attrMenu; $py++ }
            $py++
            $box = '> ' + $script:inputText
            if ($box.Length -gt $wrapW) { $box = '> ~' + $box.Substring($box.Length - ($wrapW-3)) }
            Write-LineAt ($px+2) $py $box.PadRight($wrapW) $attrSel
            $py += 2
            Write-LineAt ($px+2) $py 'Enter=OK  Esc=Cancel' $attrMenu
        } elseif ($script:mode -eq 'info') {
            foreach ($ln in $script:infoLines) {
                if ($py -ge ($h-$footerH-1)) { break }
                $chunk = $ln
                $wrapW = $menuPaneW - 4
                if ($chunk.Length -gt $wrapW) { $chunk = $chunk.Substring(0,$wrapW-1)+'~' }
                Write-LineAt ($px+2) $py $chunk $attrMenu
                $py++
            }
            $py = $h-$footerH-2
            $label = '[ Close ]'
            Write-LineAt ($px+2) $py $label $attrMenuSel
            $script:uiHitRegions += [pscustomobject]@{ Kind='info'; Index=0; X1=($px+2); X2=($px+2+$label.Length); Y=$py }
        }
    }

    # Status/footer
    $status = " $($script:statusMsg)"
    if ($script:items.Count -gt 0 -and $script:selected -ge 0 -and $script:selected -lt $script:items.Count) {
        $sel = $script:items[$script:selected]
        $status = (' ' + $sel.Name + '  |  ' + $script:statusMsg)
    }
    Write-LineAt 0 ($h-1) $status $attrStatus
}

$script:hoverIndex = -1
$script:hoverMenuIndex = -1
$script:uiHitRegions = @()

function Get-ListHit([int]$mx, [int]$my, [int]$w, [int]$h) {
    $listTop = 2; $footerH = 2
    $menuPaneW = 0
    if ($script:mode -in @('menu','confirm','input','info')) { $menuPaneW = [Math]::Min(44, [Math]::Max(28, [int]($w * 0.38))) }
    $listW = $w - $menuPaneW
    $listH = [Math]::Max(1, $h - $listTop - $footerH)
    $rowStart = $listTop + 1
    $visible = $listH - 1
    if ($mx -lt 0 -or $mx -ge $listW) { return -1 }
    if ($my -lt $rowStart -or $my -ge ($rowStart + $visible)) { return -1 }
    $idx = $script:scroll + ($my - $rowStart)
    if ($idx -ge 0 -and $idx -lt $script:items.Count) { return $idx }
    return -1
}

function Handle-ActivateSelection {
    if ($script:items.Count -eq 0) { return }
    if ($script:selected -lt 0 -or $script:selected -ge $script:items.Count) { return }
    Open-SelectedItem
}

function Go-UpFolder {
    $target = Get-ParentPath $script:currentPath
    if ($target) {
        try { $script:currentPath = (Resolve-Path -LiteralPath $target).ProviderPath; $script:selected=0; $script:scroll=0; Refresh-Items; $script:statusMsg='Up one folder.' }
        catch { $script:statusMsg = "Cannot go up: $($_.Exception.Message)" }
    } else { $script:statusMsg = 'Already at root.' }
}

# Main loop
Refresh-Items
$running = $true
$buf = New-Object OM.INPUT_RECORD[] 64
$prevW = -1; $prevH = -1
try {
    try { [Console]::CursorVisible = $false } catch {}
    Clear-ScreenBuffer
    while ($running) {
        $sz = Get-BufferSize
        if ($sz.Width -ne $prevW -or $sz.Height -ne $prevH) { $prevW=$sz.Width; $prevH=$sz.Height; Clear-ScreenBuffer }
        Draw-UI
        $read = 0
        $ok = [OM.ConsoleApi]::ReadConsoleInput($script:hIn, $buf, [System.UInt32]$buf.Length, [ref]$read)
        if (-not $ok -or $read -le 0) { Start-Sleep -Milliseconds 10; continue }
        for ($e=0; $e -lt $read; $e++) {
            $rec = $buf[$e]
            if ($rec.EventType -eq [OM.ConsoleApi]::WINDOW_BUFFER_SIZE_EVENT) { Clear-ScreenBuffer; continue }
            if ($rec.EventType -eq [OM.ConsoleApi]::KEY_EVENT) {
                $k = $rec.KeyEvent
                if (-not $k.bKeyDown) { continue }
                $vk = [int]$k.wVirtualKeyCode
                $ch = $k.UnicodeChar
                if ($script:mode -eq 'input') {
                    if ($vk -eq 27) { $script:mode='browse'; $script:statusMsg='Input cancelled.' }
                    elseif ($vk -eq 13) {
                        $action=$script:inputAction; $txt=$script:inputText
                        try { & $action $txt } catch { $script:mode='browse'; $script:statusMsg = "Action failed: $($_.Exception.Message)" }
                    }
                    elseif ($vk -eq 8) { if ($script:inputText.Length -gt 0) { $script:inputText = $script:inputText.Substring(0,$script:inputText.Length-1) } }
                    elseif ($ch -and [int][char]$ch -ge 32) { $script:inputText += $ch }
                    continue
                }
                if ($script:mode -eq 'info') {
                    if ($vk -in @(13,27,32)) { $script:mode='browse'; $script:statusMsg='Closed info.' }
                    continue
                }
                if ($script:mode -eq 'confirm') {
                    if ($vk -eq 37 -or $vk -eq 38) { $script:confirmIndex = 0 }
                    elseif ($vk -eq 39 -or $vk -eq 40) { $script:confirmIndex = 1 }
                    elseif ($vk -eq 27) { $act=$script:confirmAction; try { & $act $false } catch { $script:mode='browse'; $script:statusMsg = "Action failed: $($_.Exception.Message)" } }
                    elseif ($vk -eq 13) { $ans = ($script:confirmIndex -eq 0); $act=$script:confirmAction; try { & $act $ans } catch { $script:mode='browse'; $script:statusMsg = "Action failed: $($_.Exception.Message)" } }
                    elseif ($ch -eq 'y' -or $ch -eq 'Y') { $act=$script:confirmAction; try { & $act $true } catch { $script:mode='browse'; $script:statusMsg = "Action failed: $($_.Exception.Message)" } }
                    elseif ($ch -eq 'n' -or $ch -eq 'N') { $act=$script:confirmAction; try { & $act $false } catch { $script:mode='browse'; $script:statusMsg = "Action failed: $($_.Exception.Message)" } }
                    continue
                }
                if ($script:mode -eq 'menu') {
                    if ($vk -eq 38) { if ($script:menuIndex -gt 0) { $script:menuIndex-- } }
                    elseif ($vk -eq 40) { if ($script:menuIndex -lt ($script:menuButtons.Count-1)) { $script:menuIndex++ } }
                    elseif ($vk -eq 27) { $script:mode='browse'; $script:statusMsg='Menu closed.' }
                    elseif ($vk -eq 13) { Invoke-MenuAction $script:menuButtons[$script:menuIndex] }
                    continue
                }
                # browse mode
                if ($vk -eq 27) { $running = $false }
                elseif ($vk -eq 38) { if ($script:selected -gt 0) { $script:selected-- } }
                elseif ($vk -eq 40) { if ($script:selected -lt ($script:items.Count-1)) { $script:selected++ } }
                elseif ($vk -eq 13) { Handle-ActivateSelection }
                elseif ($vk -eq 8) { Go-UpFolder }
                elseif ($ch -eq 'n' -or $ch -eq 'N') { Do-CreateNew }
                elseif ($ch -eq 'm' -or $ch -eq 'M') {
                    if ($script:items.Count -gt 0 -and $script:selected -ge 0 -and $script:selected -lt $script:items.Count) { Show-ActionMenu $script:items[$script:selected] }
                }
                elseif ($ch -eq 'c' -or $ch -eq 'C') { Do-CustomCommand }
                elseif ($vk -eq 33) { $script:selected = [Math]::Max(0, $script:selected - 10) } # PgUp
                elseif ($vk -eq 34) { $script:selected = [Math]::Min([Math]::Max(0,$script:items.Count-1), $script:selected + 10) } # PgDn
                elseif ($vk -eq 36) { $script:selected = 0 } # Home
                elseif ($vk -eq 35) { $script:selected = [Math]::Max(0,$script:items.Count-1) } # End
            }
            elseif ($rec.EventType -eq [OM.ConsoleApi]::MOUSE_EVENT) {
                $m = $rec.MouseEvent
                $mx = [int]$m.dwMousePosition.X
                $my = [int]$m.dwMousePosition.Y - $sz.Top
                $flags = $m.dwEventFlags
                $btn = $m.dwButtonState
                # Hover tracking
                $script:hoverIndex = Get-ListHit $mx $my $sz.Width $sz.Height
                $script:hoverMenuIndex = -1
                foreach ($hr in $script:uiHitRegions) {
                    if ($hr.Kind -eq 'menu' -and $my -eq $hr.Y -and $mx -ge $hr.X1 -and $mx -lt $hr.X2) { $script:hoverMenuIndex = $hr.Index }
                }
                # Wheel
                if (($flags -band [OM.ConsoleApi]::MOUSE_WHEELED) -ne 0) {
                    $delta = [int]($btn -shr 16)
                    if ($delta -gt 32767) { $delta = $delta - 65536 } # signed high word
                    if ($script:mode -eq 'browse') {
                        if ($delta -gt 0) { $script:selected = [Math]::Max(0, $script:selected - 3) }
                        else { $script:selected = [Math]::Min([Math]::Max(0,$script:items.Count-1), $script:selected + 3) }
                    } elseif ($script:mode -eq 'menu') {
                        if ($delta -gt 0) { $script:menuIndex = [Math]::Max(0, $script:menuIndex - 1) }
                        else { $script:menuIndex = [Math]::Min($script:menuButtons.Count-1, $script:menuIndex + 1) }
                    }
                }
                # Click
                $isClick = (($flags -eq 0) -and (($btn -band [OM.ConsoleApi]::FROM_LEFT_1ST_BUTTON_PRESSED) -ne 0))
                if ($isClick) {
                    # Check UI regions first
                    $handled = $false
                    foreach ($hr in $script:uiHitRegions) {
                        if ($my -eq $hr.Y -and $mx -ge $hr.X1 -and $mx -lt $hr.X2) {
                            if ($hr.Kind -eq 'menu') { $script:menuIndex = $hr.Index; Invoke-MenuAction $script:menuButtons[$hr.Index]; $handled=$true; break }
                            if ($hr.Kind -eq 'confirm') { $ans = ($hr.Index -eq 0); $act=$script:confirmAction; & $act $ans; $handled=$true; break }
                            if ($hr.Kind -eq 'info') { $script:mode='browse'; $script:statusMsg='Closed info.'; $handled=$true; break }
                        }
                    }
                    if (-not $handled) {
                        $hit = Get-ListHit $mx $my $sz.Width $sz.Height
                        if ($hit -ge 0) {
                            if ($script:mode -eq 'browse') {
                                $script:selected = $hit
                                $it = $script:items[$hit]
                                if ($it.IsDir) { Open-SelectedItem } else { Show-ActionMenu $it }
                            }
                        }
                    }
                }
            }
        }
    }
}
finally {
    try { [Console]::CursorVisible = $true } catch {}
    try { [OM.ConsoleApi]::SetConsoleMode($script:hIn, $script:origInMode) } catch {}
    Clear-ScreenBuffer
    Write-Host "Operations Manager exited." -ForegroundColor Cyan
}
