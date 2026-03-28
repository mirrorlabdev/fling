# ── Fling v2.1 — Floating Input Sender (WPF) ───────────
# Write once, send anywhere.
# Ctrl+` : global hotkey (show/hide)
# Enter  : send to last active window
# Shift+Enter : newline
# Drag files/links/images/text : smart insert
# Key Mode (Ctrl+Alt+Shift+Z) : record keystrokes as {tokens}
# ───────────────────────────────────────────────────────

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ── Win32 API ──
$memberDef = '[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, ref uint processId);
[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
[DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
[DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
[DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);'

if (-not ([System.Management.Automation.PSTypeName]'Fling.W32').Type) {
    Add-Type -MemberDefinition $memberDef -Name W32 -Namespace Fling
}

function ForceForeground([IntPtr]$hwnd) {
    [uint32]$procId = 0
    $targetThread = [Fling.W32]::GetWindowThreadProcessId($hwnd, [ref]$procId)
    $currentThread = [Fling.W32]::GetCurrentThreadId()
    [Fling.W32]::AttachThreadInput($currentThread, $targetThread, $true) | Out-Null
    [Fling.W32]::SetForegroundWindow($hwnd) | Out-Null
    [Fling.W32]::AttachThreadInput($currentThread, $targetThread, $false) | Out-Null
}

function SendKeystroke([byte]$vk) {
    $KEYDOWN = [uint32]0; $KEYUP = [uint32]2; $zero = [UIntPtr]::Zero
    [Fling.W32]::keybd_event($vk, 0, $KEYDOWN, $zero)
    [Fling.W32]::keybd_event($vk, 0, $KEYUP, $zero)
}

function SendKeyCombo([byte[]]$modifiers, [byte]$vk) {
    $KEYDOWN = [uint32]0; $KEYUP = [uint32]2; $zero = [UIntPtr]::Zero
    foreach ($m in $modifiers) { [Fling.W32]::keybd_event($m, 0, $KEYDOWN, $zero) }
    [Fling.W32]::keybd_event($vk, 0, $KEYDOWN, $zero)
    [Fling.W32]::keybd_event($vk, 0, $KEYUP, $zero)
    foreach ($m in ($modifiers | Sort-Object -Descending)) { [Fling.W32]::keybd_event($m, 0, $KEYUP, $zero) }
}

function SendCtrlV {
    SendKeyCombo @(0x11) 0x56
}

function SendEnterKey {
    SendKeystroke 0x0D
}

# ── Key token → VK mapping ──
$script:keyTokenMap = @{
    'Enter' = @{ vk = 0x0D; mods = @() }
    'Tab' = @{ vk = 0x09; mods = @() }
    'Backspace' = @{ vk = 0x08; mods = @() }
    'Delete' = @{ vk = 0x2E; mods = @() }
    'Escape' = @{ vk = 0x1B; mods = @() }
    'Space' = @{ vk = 0x20; mods = @() }
    'Up' = @{ vk = 0x26; mods = @() }
    'Down' = @{ vk = 0x28; mods = @() }
    'Left' = @{ vk = 0x25; mods = @() }
    'Right' = @{ vk = 0x27; mods = @() }
    'Home' = @{ vk = 0x24; mods = @() }
    'End' = @{ vk = 0x23; mods = @() }
    'PageUp' = @{ vk = 0x21; mods = @() }
    'PageDown' = @{ vk = 0x22; mods = @() }
    'F1' = @{ vk = 0x70; mods = @() }; 'F2' = @{ vk = 0x71; mods = @() }
    'F3' = @{ vk = 0x72; mods = @() }; 'F4' = @{ vk = 0x73; mods = @() }
    'F5' = @{ vk = 0x74; mods = @() }; 'F6' = @{ vk = 0x75; mods = @() }
    'F7' = @{ vk = 0x76; mods = @() }; 'F8' = @{ vk = 0x77; mods = @() }
    'F9' = @{ vk = 0x78; mods = @() }; 'F10' = @{ vk = 0x79; mods = @() }
    'F11' = @{ vk = 0x7A; mods = @() }; 'F12' = @{ vk = 0x7B; mods = @() }
}

# Modifier VK codes
$script:modVkMap = @{
    'Ctrl' = 0x11; 'Alt' = 0x12; 'Shift' = 0x10
}

function ParseKeyToken([string]$token) {
    # Parse tokens like "Down", "Ctrl+Z", "Shift+Tab"
    $parts = $token -split '\+'
    [byte[]]$mods = @()
    $keyPart = ''
    foreach ($p in $parts) {
        $p = $p.Trim()
        if ($script:modVkMap.ContainsKey($p)) {
            $mods += [byte]$script:modVkMap[$p]
        } else {
            $keyPart = $p
        }
    }
    if (-not $keyPart) { return $null }

    # Check known tokens first
    if ($script:keyTokenMap.ContainsKey($keyPart)) {
        $entry = $script:keyTokenMap[$keyPart]
        return @{ vk = [byte]$entry.vk; mods = $mods }
    }
    # Single letter/digit
    if ($keyPart.Length -eq 1) {
        $ch = [char]$keyPart.ToUpper()
        if (($ch -ge 'A' -and $ch -le 'Z') -or ($ch -ge '0' -and $ch -le '9')) {
            return @{ vk = [byte][char]$ch; mods = $mods }
        }
    }
    # Try WinForms Keys enum
    try {
        $vk = [System.Windows.Forms.Keys]::$keyPart
        return @{ vk = [byte][int]$vk; mods = $mods }
    } catch {}
    return $null
}

# ── Target hint (cached StringBuilder) ──
$script:hintSb = New-Object System.Text.StringBuilder 256

function GetTargetHint([IntPtr]$hwnd) {
    if ($hwnd -eq [IntPtr]::Zero) { return '' }
    [uint32]$hintPid = 0
    [Fling.W32]::GetWindowThreadProcessId($hwnd, [ref]$hintPid) | Out-Null
    $procName = ''
    try {
        $proc = [System.Diagnostics.Process]::GetProcessById([int]$hintPid)
        $procName = $proc.ProcessName
        $proc.Dispose()
    } catch {}
    $script:hintSb.Length = 0
    [Fling.W32]::GetWindowText($hwnd, $script:hintSb, 256) | Out-Null
    $title = $script:hintSb.ToString()
    if ($title.Length -gt 40) { $title = $title.Substring(0, 37) + '...' }
    if ($title) { return "$procName  ($title)" }
    return $procName
}

# ── Settings ──
$settingsPath = Join-Path $PSScriptRoot 'fling-settings.json'
$defaults = @{
    x = 200; y = 840; w = 720; h = 170
    topMost = $true
    clearAfterSend = $true
    autoEnter = $true
    autoHide = $false
    pathOnly = $false
    hotkey = 'Ctrl+Oem3'
    hkQuickPaste = 'Ctrl+Alt+V'
    keyMode = 'Ctrl+K'
    keyModeExit = 'Escape'
    ikToggleClear = ''
    ikToggleEnter = ''
    ikSendEnter = ''
    opacity = 0.95
    fontSize = 14
}

function LoadSettings {
    if (Test-Path $settingsPath) {
        try {
            $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
            $out = @{}
            foreach ($k in $defaults.Keys) {
                if ($null -ne $json.$k) { $out[$k] = $json.$k } else { $out[$k] = $defaults[$k] }
            }
            return $out
        } catch {}
    }
    return $defaults.Clone()
}

$settings = LoadSettings
$script:targetHwnd = [IntPtr]::Zero
$script:sendStep   = 'idle'
$script:oldClipText = $null
$script:hotkeyName = $settings.hotkey
$script:keyMode = $false

# ── WPF Window (XAML) ──
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Fling" WindowStyle="None" AllowsTransparency="True"
        ShowInTaskbar="False" Background="Transparent"
        ResizeMode="CanResizeWithGrip">
    <Border Name="bgBorder" Background="#1e1e2e" CornerRadius="6" Padding="2">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="20"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="30"/>
        </Grid.RowDefinitions>

        <!-- Target hint (draggable) + close button -->
        <DockPanel Grid.Row="0" Background="Transparent" Name="dpTitle">
            <Button Name="btnClose" DockPanel.Dock="Right" Content="&#x2715;"
                    Width="24" Height="18" FontSize="10"
                    Foreground="#646478" Background="Transparent"
                    BorderThickness="0" Cursor="Hand" VerticalAlignment="Center"/>
            <TextBlock Name="lblTarget" Text="Ctrl+``  show/hide"
                       Foreground="#646478" FontSize="11" FontFamily="Segoe UI"
                       Padding="8,2,0,0" VerticalAlignment="Center"/>
        </DockPanel>

        <!-- Main input -->
        <TextBox Name="tbInput" Grid.Row="1"
                 FontSize="14" FontFamily="Segoe UI"
                 Background="#181825" Foreground="#cdd6f4"
                 CaretBrush="#10b981" SelectionBrush="#10b981"
                 AcceptsReturn="True" TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto"
                 BorderThickness="0" Padding="8,4,8,4"
                 AllowDrop="True" UndoLimit="100"/>

        <!-- Bottom bar -->
        <DockPanel Name="dpBottom" Grid.Row="2" Background="#1e1e2e">
            <Button Name="btnGear" DockPanel.Dock="Right" Content="&#x2699;"
                    Width="28" Height="24" Margin="0,0,4,0"
                    FontSize="14" Foreground="#646478" Background="Transparent"
                    BorderThickness="0" Cursor="Hand"/>
            <StackPanel Name="spBottom" Orientation="Horizontal"
                        VerticalAlignment="Center"/>
        </DockPanel>
    </Grid>
    </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Get controls
$lblTarget = $window.FindName('lblTarget')
$tbInput   = $window.FindName('tbInput')
$spBottom  = $window.FindName('spBottom')
$btnGear   = $window.FindName('btnGear')
$dpBottom  = $window.FindName('dpBottom')
$bgBorder  = $window.FindName('bgBorder')
$dpTitle   = $window.FindName('dpTitle')
$btnClose  = $window.FindName('btnClose')

# Cache own window handle (fix memory leak — was creating WindowInteropHelper every 200ms)
$script:myHwnd = [IntPtr]::Zero

# Drag to move
$dpTitle.Add_MouseLeftButtonDown({ $window.DragMove() })

# Close button
$btnClose.Add_Click({ $window.Close() })

# Close button hover
$closeTemplate = [System.Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <Border Name="bd" Background="Transparent" CornerRadius="2" Padding="{TemplateBinding Padding}">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
    <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="bd" Property="Background" Value="#e74c3c"/>
        </Trigger>
    </ControlTemplate.Triggers>
</ControlTemplate>
'@)
$btnClose.Template = $closeTemplate

# Apply settings
$window.Width   = $settings.w
$window.Height  = $settings.h
$window.Left    = $settings.x
$window.Top     = $settings.y
$window.Topmost = $settings.topMost
$bgBorder.Opacity = $settings.opacity
$tbInput.FontSize = $settings.fontSize

# ── Toggle Button Helper (WPF + custom template) ──
$bc = [System.Windows.Media.BrushConverter]::new()
$accentBrush = $bc.ConvertFrom('#10b981')
$offBrush    = $bc.ConvertFrom('#2d2d41')
$offFg       = $bc.ConvertFrom('#78788c')
$keyModeBrush = $bc.ConvertFrom('#f59e0b')

$toggleTemplateXaml = @'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 TargetType="ToggleButton">
    <Border Name="bd" Background="{TemplateBinding Background}"
            BorderBrush="{TemplateBinding BorderBrush}"
            BorderThickness="{TemplateBinding BorderThickness}"
            CornerRadius="2" Padding="{TemplateBinding Padding}">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
</ControlTemplate>
'@
$toggleTemplate = [System.Windows.Markup.XamlReader]::Parse($toggleTemplateXaml)

$gearTemplateXaml = @'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 TargetType="Button">
    <Border Name="bd" Background="{TemplateBinding Background}"
            BorderThickness="0" Padding="{TemplateBinding Padding}">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
</ControlTemplate>
'@
$gearTemplate = [System.Windows.Markup.XamlReader]::Parse($gearTemplateXaml)
$btnGear.Template = $gearTemplate

function ApplyToggleStyle($b) {
    if ($b.IsChecked) {
        $b.Background  = $accentBrush
        $b.Foreground  = [System.Windows.Media.Brushes]::White
        $b.BorderBrush = $accentBrush
    } else {
        $b.Background  = $offBrush
        $b.Foreground  = $offFg
        $b.BorderBrush = $offBrush
    }
}

function MakeWpfToggle($text, $checked) {
    $btn = New-Object System.Windows.Controls.Primitives.ToggleButton
    $btn.Content    = $text
    $btn.IsChecked  = $checked
    $btn.FontSize   = 11
    $btn.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe UI')
    $btn.Height     = 24
    $btn.Padding    = New-Object System.Windows.Thickness(8, 2, 8, 2)
    $btn.Margin     = New-Object System.Windows.Thickness(2, 0, 2, 0)
    $btn.BorderThickness = New-Object System.Windows.Thickness(1)
    $btn.Cursor     = [System.Windows.Input.Cursors]::Hand
    $btn.Template   = $toggleTemplate

    ApplyToggleStyle $btn
    $btn.Add_Checked({  param($s,$e); ApplyToggleStyle $s })
    $btn.Add_Unchecked({ param($s,$e); ApplyToggleStyle $s })

    return $btn
}

$chkClear = MakeWpfToggle 'Clear after send' $settings.clearAfterSend
$chkEnter = MakeWpfToggle 'Auto Enter' $settings.autoEnter
$chkHide  = MakeWpfToggle 'Auto Hide' $settings.autoHide
$chkPath  = MakeWpfToggle 'File: path only' $settings.pathOnly
$chkOnTop = MakeWpfToggle 'Always on top' $settings.topMost

$chkOnTop.Add_Checked({  $window.Topmost = $true })
$chkOnTop.Add_Unchecked({ $window.Topmost = $false })

$spBottom.Children.Add($chkClear) | Out-Null
$spBottom.Children.Add($chkEnter) | Out-Null
$spBottom.Children.Add($chkHide) | Out-Null
$spBottom.Children.Add($chkPath) | Out-Null
$spBottom.Children.Add($chkOnTop) | Out-Null

# ── Key Mode indicator ──
function UpdateKeyModeUI {
    if ($script:keyMode) {
        $lblTarget.Text = 'KEY MODE  (press toggle hotkey to exit)'
        $lblTarget.Foreground = $keyModeBrush
        $tbInput.BorderBrush = $keyModeBrush
        $tbInput.BorderThickness = New-Object System.Windows.Thickness(2)
    } else {
        $lblTarget.Foreground = $bc.ConvertFrom('#646478')
        $tbInput.BorderBrush = $null
        $tbInput.BorderThickness = New-Object System.Windows.Thickness(0)
        # Restore target hint
        if ($script:targetHwnd -ne [IntPtr]::Zero) {
            $hint = GetTargetHint $script:targetHwnd
            $lblTarget.Text = [char]0x2192 + " $hint"
        } else {
            $lblTarget.Text = "Ctrl+``  show/hide"
        }
    }
}

# ── Save Settings ──
function SaveSettings {
    $s = @{
        x = [int]$window.Left; y = [int]$window.Top
        w = [int]$window.Width; h = [int]$window.Height
        topMost = [bool]$window.Topmost
        clearAfterSend = [bool]$chkClear.IsChecked
        autoEnter = [bool]$chkEnter.IsChecked
        autoHide = [bool]$chkHide.IsChecked
        pathOnly = [bool]$chkPath.IsChecked
        hotkey = $script:hotkeyName
        hkQuickPaste = $settings.hkQuickPaste
        keyMode = $settings.keyMode
        keyModeExit = $settings.keyModeExit
        ikToggleClear = $settings.ikToggleClear
        ikToggleEnter = $settings.ikToggleEnter
        ikSendEnter = $settings.ikSendEnter
        opacity = $bgBorder.Opacity
        fontSize = $tbInput.FontSize
    }
    $s | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8
}

# ── Drop handler (files, web links, web images, text) ──
$textContentExts = @('.md', '.txt')

$tbInput.Add_PreviewDragOver({
    param($sender, $e)
    $e.Handled = $true
    # Accept all drag types
    $e.Effects = [System.Windows.DragDropEffects]::Copy
})

$tbInput.Add_Drop({
    param($sender, $e)
    $insert = $null

    # 1) File drop (local files)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        foreach ($f in $files) {
            $ext = [System.IO.Path]::GetExtension($f).ToLower()
            $fileName = [System.IO.Path]::GetFileName($f)
            if ($chkPath.IsChecked) {
                $insert = $f
            } elseif ($textContentExts -contains $ext) {
                $content = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
                $insert = "[$fileName]`r`n$content"
            } else {
                $insert = $f
            }
        }
    }
    # 2) URL drop (web links, web images)
    elseif ($e.Data.GetDataPresent('UniformResourceLocator')) {
        try {
            $url = $e.Data.GetData('UniformResourceLocator')
            if ($url -is [System.IO.Stream]) {
                $sr = New-Object System.IO.StreamReader($url)
                $insert = $sr.ReadToEnd().Trim("`0", "`r", "`n")
                $sr.Dispose()
            } elseif ($url -is [string]) {
                $insert = $url.Trim()
            }
        } catch {}
    }
    # 3) HTML fallback (extract href)
    elseif ($e.Data.GetDataPresent('HTML Format')) {
        try {
            $html = $e.Data.GetData('HTML Format')
            if ($html -match 'href="([^"]+)"') {
                $insert = $Matches[1]
            } elseif ($html -match 'src="([^"]+)"') {
                $insert = $Matches[1]
            }
        } catch {}
    }
    # 4) Plain text fallback
    elseif ($e.Data.GetDataPresent([System.Windows.DataFormats]::UnicodeText)) {
        $insert = $e.Data.GetData([System.Windows.DataFormats]::UnicodeText)
    }
    elseif ($e.Data.GetDataPresent([System.Windows.DataFormats]::Text)) {
        $insert = $e.Data.GetData([System.Windows.DataFormats]::Text)
    }

    if ($insert) {
        $pos = $tbInput.CaretIndex
        $tbInput.Text = $tbInput.Text.Insert($pos, $insert)
        $tbInput.CaretIndex = $pos + $insert.Length
    }
})

# ── Ctrl+Wheel Font Size ──
$tbInput.Add_PreviewMouseWheel({
    param($sender, $e)
    if ([System.Windows.Input.Keyboard]::Modifiers -eq [System.Windows.Input.ModifierKeys]::Control) {
        $e.Handled = $true
        $sz = $tbInput.FontSize
        if ($e.Delta -gt 0) { $sz += 1 } else { $sz -= 1 }
        if ($sz -lt 8) { $sz = 8 }
        if ($sz -gt 36) { $sz = 36 }
        $tbInput.FontSize = $sz
    }
})

# ── Target tracking (DispatcherTimer) — memory leak fixed ──
$trackTimer = New-Object System.Windows.Threading.DispatcherTimer
$trackTimer.Interval = [TimeSpan]::FromMilliseconds(200)
$trackTimer.Add_Tick({
    $hwnd = [Fling.W32]::GetForegroundWindow()
    if ($hwnd -ne [IntPtr]::Zero -and $hwnd -ne $script:myHwnd) {
        $script:targetHwnd = $hwnd
        if (-not $script:keyMode) {
            $hint = GetTargetHint $hwnd
            $lblTarget.Text = [char]0x2192 + " $hint"
        }
    }
})

# ── Send sequence engine ──
# Parses text with «Token» markers and sends as mixed clipboard paste + keystrokes
$script:sendQueue = @()
$script:sendQueueIdx = 0
$script:seqDone = $false

$seqTimer = New-Object System.Windows.Threading.DispatcherTimer
$seqTimer.Interval = [TimeSpan]::FromMilliseconds(80)
$seqTimer.Add_Tick({
    $seqTimer.Stop()

    # Cleanup phase
    if ($script:seqDone) {
        if ($script:oldClipText) {
            try { [System.Windows.Clipboard]::SetText($script:oldClipText) } catch {}
            $script:oldClipText = $null
        }
        if ($chkHide.IsChecked) {
            $window.Hide()
        } else {
            $window.Activate()
            $tbInput.Focus()
        }
        $script:sendStep = 'idle'
        $script:sendQueue = @()
        $script:sendQueueIdx = 0
        $script:seqDone = $false
        return
    }

    if ($script:sendQueueIdx -ge $script:sendQueue.Count) {
        # All items sent — schedule cleanup
        $script:seqDone = $true
        $seqTimer.Interval = [TimeSpan]::FromMilliseconds(80)
        $seqTimer.Start()
        return
    }

    $item = $script:sendQueue[$script:sendQueueIdx]
    $script:sendQueueIdx++

    if ($item.type -eq 'keys') {
        $parsed = ParseKeyToken $item.value
        if ($parsed) {
            if ($parsed.mods.Count -gt 0) {
                SendKeyCombo $parsed.mods $parsed.vk
            } else {
                SendKeystroke $parsed.vk
            }
        }
        $seqTimer.Interval = [TimeSpan]::FromMilliseconds(80)
    }
    elseif ($item.type -eq 'text') {
        [System.Windows.Clipboard]::SetText($item.value)
        Start-Sleep -Milliseconds 30
        SendCtrlV
        $seqTimer.Interval = [TimeSpan]::FromMilliseconds(120)
    }

    $seqTimer.Start()
})

function BuildSendQueue([string]$text) {
    $queue = @()
    $pattern = [char]0xAB + '([^' + [char]0xBB + ']+)' + [char]0xBB  # «...»
    $lastEnd = 0
    $matches2 = [regex]::Matches($text, $pattern)

    foreach ($m in $matches2) {
        if ($m.Index -gt $lastEnd) {
            $chunk = $text.Substring($lastEnd, $m.Index - $lastEnd)
            if ($chunk.Length -gt 0) {
                $queue += @{ type = 'text'; value = $chunk }
            }
        }
        $queue += @{ type = 'keys'; value = $m.Groups[1].Value }
        $lastEnd = $m.Index + $m.Length
    }
    if ($lastEnd -lt $text.Length) {
        $chunk = $text.Substring($lastEnd)
        if ($chunk.Length -gt 0) {
            $queue += @{ type = 'text'; value = $chunk }
        }
    }
    return $queue
}

# ── Send function ──
function DoSend {
    $text = $tbInput.Text.TrimEnd("`r", "`n")
    if ([string]::IsNullOrWhiteSpace($text)) {
        $tbInput.Clear()
        return
    }
    if ($script:sendStep -ne 'idle') { return }
    $script:sendStep = 'sending'

    # Turn off key mode if active
    if ($script:keyMode) {
        $script:keyMode = $false
        UpdateKeyModeUI
    }

    # Clipboard backup
    $script:oldClipText = $null
    if ([System.Windows.Clipboard]::ContainsText()) {
        $script:oldClipText = [System.Windows.Clipboard]::GetText()
    }

    if ($chkClear.IsChecked) {
        $tbInput.SelectAll()
        $tbInput.SelectedText = ''
    } else {
        $tbInput.Text = $text
        $tbInput.CaretIndex = $tbInput.Text.Length
    }

    if ($script:targetHwnd -eq [IntPtr]::Zero) { $script:sendStep = 'idle'; return }

    ForceForeground $script:targetHwnd

    # Check if text has key tokens («...»)
    $tokenChar = [char]0xAB  # «
    $hasTokens = $text.Contains($tokenChar)

    if ($hasTokens) {
        $script:sendQueue = @(BuildSendQueue $text)
        $script:sendQueueIdx = 0
        $script:seqDone = $false
        # Auto-enter: append Enter unless last token is already Enter
        if ($chkEnter.IsChecked) {
            $needEnter = $true
            if ($script:sendQueue.Count -gt 0) {
                $last = $script:sendQueue[$script:sendQueue.Count - 1]
                if ($last.type -eq 'keys' -and $last.value -eq 'Enter') { $needEnter = $false }
            }
            if ($needEnter) {
                $script:sendQueue += @{ type = 'keys'; value = 'Enter' }
            }
        }
        $seqTimer.Interval = [TimeSpan]::FromMilliseconds(80)
        $seqTimer.Start()
    } else {
        # Simple send (original path)
        [System.Windows.Clipboard]::SetText($text)
        $script:sendStep = 'paste'
        $sendTimer.Start()
    }
}

# ── Legacy send timer (simple text, no tokens) ──
$sendTimer = New-Object System.Windows.Threading.DispatcherTimer
$sendTimer.Interval = [TimeSpan]::FromMilliseconds(150)
$sendTimer.Add_Tick({
    $sendTimer.Stop()
    switch ($script:sendStep) {
        'paste' {
            SendCtrlV
            if ($chkEnter.IsChecked) {
                $script:sendStep = 'enter'
                $sendTimer.Interval = [TimeSpan]::FromMilliseconds(250)
                $sendTimer.Start()
            } else {
                $script:sendStep = 'refocus'
                $sendTimer.Interval = [TimeSpan]::FromMilliseconds(40)
                $sendTimer.Start()
            }
        }
        'enter' {
            SendEnterKey
            $script:sendStep = 'refocus'
            $sendTimer.Interval = [TimeSpan]::FromMilliseconds(40)
            $sendTimer.Start()
        }
        'refocus' {
            if ($script:oldClipText) {
                try { [System.Windows.Clipboard]::SetText($script:oldClipText) } catch {}
                $script:oldClipText = $null
            }
            if ($chkHide.IsChecked) {
                $window.Hide()
            } else {
                $window.Activate()
                $tbInput.Focus()
            }
            $script:sendStep = 'idle'
            $sendTimer.Interval = [TimeSpan]::FromMilliseconds(150)
        }
    }
})

# ── Key events ──
$tbInput.Add_PreviewKeyDown({
    param($sender, $e)

    # Key Mode: intercept all keys and insert as «Token»
    if ($script:keyMode) {
        $e.Handled = $true

        $wpfKey = $e.Key
        if ($wpfKey -eq [System.Windows.Input.Key]::System) { $wpfKey = $e.SystemKey }

        # Resolve IME-processed keys (Korean IME → ProcessKey → actual key)
        if ($wpfKey -eq [System.Windows.Input.Key]::ImeProcessed) {
            $wpfKey = $e.ImeProcessedKey
            if ($wpfKey -eq [System.Windows.Input.Key]::Undefined) { return }
        }

        # Ignore bare modifier keys
        if ($wpfKey -in @([System.Windows.Input.Key]::LeftCtrl, [System.Windows.Input.Key]::RightCtrl,
                          [System.Windows.Input.Key]::LeftAlt, [System.Windows.Input.Key]::RightAlt,
                          [System.Windows.Input.Key]::LeftShift, [System.Windows.Input.Key]::RightShift)) { return }

        # Check key mode exit key (default: Escape)
        $exitKeyName = if ($settings.keyModeExit) { $settings.keyModeExit } else { 'Escape' }
        $friendlyName = switch ($wpfKey) {
            ([System.Windows.Input.Key]::Return)  { 'Enter' }
            ([System.Windows.Input.Key]::Back)    { 'Backspace' }
            ([System.Windows.Input.Key]::Tab)     { 'Tab' }
            ([System.Windows.Input.Key]::Escape)  { 'Escape' }
            ([System.Windows.Input.Key]::Space)   { 'Space' }
            ([System.Windows.Input.Key]::Delete)  { 'Delete' }
            ([System.Windows.Input.Key]::Up)      { 'Up' }
            ([System.Windows.Input.Key]::Down)    { 'Down' }
            ([System.Windows.Input.Key]::Left)    { 'Left' }
            ([System.Windows.Input.Key]::Right)   { 'Right' }
            ([System.Windows.Input.Key]::Home)    { 'Home' }
            ([System.Windows.Input.Key]::End)     { 'End' }
            ([System.Windows.Input.Key]::PageUp)  { 'PageUp' }
            ([System.Windows.Input.Key]::PageDown){ 'PageDown' }
            default {
                $vk = [System.Windows.Input.KeyInterop]::VirtualKeyFromKey($wpfKey)
                ([System.Windows.Forms.Keys]$vk).ToString()
            }
        }

        # Build modifier prefix
        $modParts = @()
        if ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) { $modParts += 'Ctrl' }
        if ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Alt)     { $modParts += 'Alt' }
        if ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift)   { $modParts += 'Shift' }

        # Check exit: no modifiers + matches exit key name
        $fullName = if ($modParts.Count -gt 0) { ($modParts -join '+') + '+' + $friendlyName } else { $friendlyName }
        if ($fullName -eq $exitKeyName) {
            $script:keyMode = $false
            UpdateKeyModeUI
            return
        }

        $modParts += $friendlyName
        $token = [char]0xAB + ($modParts -join '+') + [char]0xBB  # «...»

        # Insert at caret
        $pos = $tbInput.CaretIndex
        $tbInput.Text = $tbInput.Text.Insert($pos, $token)
        $tbInput.CaretIndex = $pos + $token.Length
        return
    }

    # Normal mode: Key Mode toggle (default Ctrl+K)
    $kmSetting = if ($settings.keyMode) { $settings.keyMode } else { 'Ctrl+K' }
    $kmParts = $kmSetting -split '\+'
    $kmKey = $kmParts[-1].Trim()
    $kmNeedCtrl  = $kmParts -contains 'Ctrl'
    $kmNeedAlt   = $kmParts -contains 'Alt'
    $kmNeedShift = $kmParts -contains 'Shift'
    $wpfKeyCheck = $e.Key
    if ($wpfKeyCheck -eq [System.Windows.Input.Key]::System) { $wpfKeyCheck = $e.SystemKey }
    $vkCheck = [System.Windows.Input.KeyInterop]::VirtualKeyFromKey($wpfKeyCheck)
    $keyNameCheck = ([System.Windows.Forms.Keys]$vkCheck).ToString()
    $mods = [System.Windows.Input.Keyboard]::Modifiers
    $hasCtrl  = [bool]($mods -band [System.Windows.Input.ModifierKeys]::Control)
    $hasAlt   = [bool]($mods -band [System.Windows.Input.ModifierKeys]::Alt)
    $hasShift = [bool]($mods -band [System.Windows.Input.ModifierKeys]::Shift)
    # In-app shortcut matcher (inline, no nested function)
    $ikChecks = @(
        @{ setting = $kmSetting;              action = 'keyMode' }
        @{ setting = $settings.ikToggleClear; action = 'toggleClear' }
        @{ setting = $settings.ikToggleEnter; action = 'toggleEnter' }
        @{ setting = $settings.ikSendEnter;   action = 'sendEnter' }
    )
    foreach ($ik in $ikChecks) {
        if (-not $ik.setting) { continue }
        $ikParts = $ik.setting -split '\+'
        $ikKey = $ikParts[-1].Trim()
        $ikCtrl  = $ikParts -contains 'Ctrl'
        $ikAlt   = $ikParts -contains 'Alt'
        $ikShift = $ikParts -contains 'Shift'
        if ($keyNameCheck -eq $ikKey -and $hasCtrl -eq $ikCtrl -and $hasAlt -eq $ikAlt -and $hasShift -eq $ikShift) {
            $e.Handled = $true
            switch ($ik.action) {
                'keyMode' {
                    $script:keyMode = $true
                    UpdateKeyModeUI
                }
                'toggleClear' { $chkClear.IsChecked = -not $chkClear.IsChecked }
                'toggleEnter' { $chkEnter.IsChecked = -not $chkEnter.IsChecked }
                'sendEnter' {
                    if ($script:targetHwnd -ne [IntPtr]::Zero) {
                        ForceForeground $script:targetHwnd
                        Start-Sleep -Milliseconds 50
                        # Release any held modifiers before sending Enter
                        $KEYUP = [uint32]2; $zero = [UIntPtr]::Zero
                        [Fling.W32]::keybd_event(0x11, 0, $KEYUP, $zero)  # Ctrl up
                        [Fling.W32]::keybd_event(0x12, 0, $KEYUP, $zero)  # Alt up
                        [Fling.W32]::keybd_event(0x10, 0, $KEYUP, $zero)  # Shift up
                        Start-Sleep -Milliseconds 30
                        SendEnterKey
                        Start-Sleep -Milliseconds 50
                        $window.Activate()
                        $tbInput.Focus()
                    }
                }
            }
            return
        }
    }

    # Normal mode: Enter = send (Shift+Enter = newline via AcceptsReturn)
    if ($e.Key -eq [System.Windows.Input.Key]::Return -and
        [System.Windows.Input.Keyboard]::Modifiers -ne [System.Windows.Input.ModifierKeys]::Shift) {
        $e.Handled = $true
        DoSend
    }
    # Force plain text paste
    if ($e.Key -eq [System.Windows.Input.Key]::V -and
        [System.Windows.Input.Keyboard]::Modifiers -eq [System.Windows.Input.ModifierKeys]::Control) {
        $e.Handled = $true
        if ([System.Windows.Clipboard]::ContainsText()) {
            $tbInput.SelectedText = [System.Windows.Clipboard]::GetText()
            $tbInput.CaretIndex = $tbInput.SelectionStart + $tbInput.SelectionLength
            $tbInput.SelectionLength = 0
        }
    }
})

# ── Global Hotkeys ──
$HK_SHOWHIDE   = 9001
$HK_QUICKPASTE = 9002

Add-Type @'
using System;
using System.Windows.Forms;

public class HotkeyWindow : NativeWindow {
    public event EventHandler HotkeyPressed;
    public int LastHotkeyId { get; private set; }
    private const int WM_HOTKEY = 0x0312;

    public HotkeyWindow() {
        CreateHandle(new CreateParams());
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY) {
            LastHotkeyId = (int)m.WParam;
            if (HotkeyPressed != null) HotkeyPressed(this, EventArgs.Empty);
        }
        base.WndProc(ref m);
    }
}
'@ -ReferencedAssemblies System.Windows.Forms

$hkWin = New-Object HotkeyWindow
$hkWin.Add_HotkeyPressed({
    $window.Dispatcher.Invoke({
        switch ($hkWin.LastHotkeyId) {
            $HK_SHOWHIDE {
                if ($window.IsVisible -and $window.IsActive) {
                    $window.Hide()
                } else {
                    $window.Show()
                    $window.Activate()
                    $tbInput.Focus()
                }
            }
            $HK_QUICKPASTE {
                # Quick Paste: send Fling text to current window (don't clear, don't show Fling)
                $text = $tbInput.Text.TrimEnd("`r", "`n")
                if ([string]::IsNullOrWhiteSpace($text)) { return }
                if ($script:sendStep -ne 'idle') { return }
                $fgHwnd = [Fling.W32]::GetForegroundWindow()
                if ($fgHwnd -eq [IntPtr]::Zero -or $fgHwnd -eq $script:myHwnd) { return }
                # Backup clipboard, paste, restore
                $oldClip = $null
                if ([System.Windows.Clipboard]::ContainsText()) {
                    $oldClip = [System.Windows.Clipboard]::GetText()
                }
                [System.Windows.Clipboard]::SetText($text)
                Start-Sleep -Milliseconds 50
                SendCtrlV
                Start-Sleep -Milliseconds 100
                if ($oldClip) {
                    try { [System.Windows.Clipboard]::SetText($oldClip) } catch {}
                }
            }
        }
    })
})

function ParseHotkey([string]$name) {
    if (-not $name) { return $null }
    $parts = $name -split '\+'
    [uint32]$mod = 0; $vkName = ''
    foreach ($p in $parts) {
        switch ($p.Trim()) {
            'Ctrl'  { $mod = $mod -bor 0x0002 }
            'Alt'   { $mod = $mod -bor 0x0001 }
            'Shift' { $mod = $mod -bor 0x0004 }
            default { $vkName = $p.Trim() }
        }
    }
    if (-not $vkName) { return $null }
    try {
        $vk = [System.Windows.Forms.Keys]::$vkName
        return @{ mod = $mod; vk = [uint32]$vk }
    } catch { return $null }
}

function RegisterAllHotkeys {
    [Fling.W32]::UnregisterHotKey($hkWin.Handle, $HK_SHOWHIDE) | Out-Null
    [Fling.W32]::UnregisterHotKey($hkWin.Handle, $HK_QUICKPASTE) | Out-Null
    $p = ParseHotkey $script:hotkeyName
    if ($p) { [Fling.W32]::RegisterHotKey($hkWin.Handle, $HK_SHOWHIDE, $p.mod, $p.vk) | Out-Null }
    $p = ParseHotkey $settings.hkQuickPaste
    if ($p) { [Fling.W32]::RegisterHotKey($hkWin.Handle, $HK_QUICKPASTE, $p.mod, $p.vk) | Out-Null }
}

# ── Gear button → settings ──
$btnGear.Add_Click({
    $dlg = New-Object System.Windows.Window
    $dlg.Title = 'Fling Settings'
    $dlg.Width = 400; $dlg.Height = 460
    $dlg.WindowStyle = 'ToolWindow'
    $dlg.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#1e1e2e')
    $dlg.Topmost = $true
    $dlg.WindowStartupLocation = 'CenterOwner'
    $dlg.Owner = $window

    $grid = New-Object System.Windows.Controls.Grid
    $dlg.Content = $grid

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = New-Object System.Windows.Thickness(20, 15, 20, 15)
    $grid.Children.Add($sp) | Out-Null

    $fgBrush   = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#cdd6f4')
    $dimBrush  = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#646478')
    $acBrush   = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#10b981')
    $hkBgBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#28283c')

    # Hotkey rows
    $hotkeyDefs = @(
        @{ label = 'Show / Hide (global)'; key = 'hotkey';       current = $script:hotkeyName }
        @{ label = 'Quick Paste (global)'; key = 'hkQuickPaste'; current = if ($settings.hkQuickPaste) { $settings.hkQuickPaste } else { 'Ctrl+Alt+V' } }
        @{ label = 'Key Mode';             key = 'keyMode';      current = if ($settings.keyMode) { $settings.keyMode } else { 'Ctrl+K' } }
        @{ label = 'Key Mode Exit';        key = 'keyModeExit'; current = if ($settings.keyModeExit) { $settings.keyModeExit } else { 'Escape' } }
        @{ label = 'Toggle Clear';         key = 'ikToggleClear'; current = if ($settings.ikToggleClear) { $settings.ikToggleClear } else { '' } }
        @{ label = 'Toggle Auto Enter';    key = 'ikToggleEnter'; current = if ($settings.ikToggleEnter) { $settings.ikToggleEnter } else { '' } }
        @{ label = 'Send Enter Only';      key = 'ikSendEnter';   current = if ($settings.ikSendEnter) { $settings.ikSendEnter } else { '' } }
    )
    $hkFields = @{}

    foreach ($def in $hotkeyDefs) {
        $row = New-Object System.Windows.Controls.DockPanel
        $row.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $def.label
        $lbl.Foreground = $fgBrush
        $lbl.FontSize = 13
        $lbl.Width = 140
        $lbl.VerticalAlignment = 'Center'
        [System.Windows.Controls.DockPanel]::SetDock($lbl, 'Left')

        $tb = New-Object System.Windows.Controls.TextBox
        $tb.Text = $def.current
        $tb.IsReadOnly = $true
        $tb.FontSize = 12
        $tb.Background = $hkBgBrush
        $tb.Foreground = $acBrush
        $tb.BorderThickness = New-Object System.Windows.Thickness(0)
        $tb.TextAlignment = 'Center'
        $tb.Padding = New-Object System.Windows.Thickness(4)
        $tb.Cursor = [System.Windows.Input.Cursors]::Hand
        $tb.Tag = $def.key

        $tb.Add_GotFocus({
            param($s, $ev)
            $s.Text = 'Press keys...'
            $s.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#ffc832')
        })

        $tb.Add_PreviewKeyDown({
            param($s, $e)
            $e.Handled = $true
            $parts = @()
            if ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) { $parts += 'Ctrl' }
            if ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Alt)     { $parts += 'Alt' }
            if ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift)   { $parts += 'Shift' }
            $wpfKey = $e.Key
            if ($wpfKey -eq [System.Windows.Input.Key]::System) { $wpfKey = $e.SystemKey }
            if ($wpfKey -in @([System.Windows.Input.Key]::LeftCtrl, [System.Windows.Input.Key]::RightCtrl,
                              [System.Windows.Input.Key]::LeftAlt, [System.Windows.Input.Key]::RightAlt,
                              [System.Windows.Input.Key]::LeftShift, [System.Windows.Input.Key]::RightShift)) { return }
            $vk = [System.Windows.Input.KeyInterop]::VirtualKeyFromKey($wpfKey)
            $keyName = ([System.Windows.Forms.Keys]$vk).ToString()
            $parts += $keyName
            $s.Text = ($parts -join '+')
            $s.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#10b981')
            [System.Windows.Input.Keyboard]::ClearFocus()
        })

        $tb.Add_PreviewMouseRightButtonDown({
            param($s, $e)
            $s.Text = ''
            $s.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#10b981')
        })

        $row.Children.Add($lbl) | Out-Null
        $row.Children.Add($tb) | Out-Null
        $sp.Children.Add($row) | Out-Null
        $hkFields[$def.key] = $tb
    }

    # Hint
    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = 'Click field + press keys  |  Right-click to clear  |  Ctrl+Wheel: font size'
    $hint.Foreground = $dimBrush
    $hint.FontSize = 10
    $hint.Margin = New-Object System.Windows.Thickness(0, 5, 0, 12)
    $sp.Children.Add($hint) | Out-Null

    # Opacity
    $opRow = New-Object System.Windows.Controls.DockPanel
    $opRow.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)

    $opLbl = New-Object System.Windows.Controls.TextBlock
    $opLbl.Text = 'Opacity'
    $opLbl.Foreground = $fgBrush
    $opLbl.FontSize = 13
    $opLbl.Width = 70
    $opLbl.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($opLbl, 'Left')

    $opVal = New-Object System.Windows.Controls.TextBlock
    $opVal.Text = [string][int]($bgBorder.Opacity * 100) + '%'
    $opVal.Foreground = $acBrush
    $opVal.FontSize = 12
    $opVal.Width = 40
    $opVal.TextAlignment = 'Right'
    $opVal.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($opVal, 'Right')

    $opSlider = New-Object System.Windows.Controls.Slider
    $opSlider.Minimum = 30
    $opSlider.Maximum = 100
    $opSlider.Value = [int]($bgBorder.Opacity * 100)
    $opSlider.TickFrequency = 10
    $opSlider.IsSnapToTickEnabled = $false
    $opSlider.VerticalAlignment = 'Center'
    $opSlider.Add_ValueChanged({
        $bgBorder.Opacity = $opSlider.Value / 100.0
        $opVal.Text = [string][int]$opSlider.Value + '%'
    })

    $opRow.Children.Add($opLbl) | Out-Null
    $opRow.Children.Add($opVal) | Out-Null
    $opRow.Children.Add($opSlider) | Out-Null
    $sp.Children.Add($opRow) | Out-Null

    # Buttons
    $btnRow = New-Object System.Windows.Controls.StackPanel
    $btnRow.Orientation = 'Horizontal'
    $btnRow.HorizontalAlignment = 'Right'
    $btnRow.Margin = New-Object System.Windows.Thickness(0, 15, 0, 0)

    $btnSave = New-Object System.Windows.Controls.Button
    $btnSave.Content = 'Save'
    $btnSave.Width = 80; $btnSave.Height = 30
    $btnSave.Background = $acBrush
    $btnSave.Foreground = [System.Windows.Media.Brushes]::White
    $btnSave.BorderThickness = New-Object System.Windows.Thickness(0)
    $btnSave.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    $btnSave.Cursor = [System.Windows.Input.Cursors]::Hand

    $btnSave.Add_Click({
        $script:hotkeyName = $hkFields['hotkey'].Text
        $settings.hkQuickPaste = $hkFields['hkQuickPaste'].Text
        $settings.keyMode = $hkFields['keyMode'].Text
        $settings.keyModeExit = $hkFields['keyModeExit'].Text
        $settings.ikToggleClear = $hkFields['ikToggleClear'].Text
        $settings.ikToggleEnter = $hkFields['ikToggleEnter'].Text
        $settings.ikSendEnter = $hkFields['ikSendEnter'].Text
        RegisterAllHotkeys
        SaveSettings
        $dlg.Close()
    })

    $btnCancel = New-Object System.Windows.Controls.Button
    $btnCancel.Content = 'Cancel'
    $btnCancel.Width = 80; $btnCancel.Height = 30
    $btnCancel.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#2d2d41')
    $btnCancel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#78788c')
    $btnCancel.BorderThickness = New-Object System.Windows.Thickness(0)
    $btnCancel.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnCancel.Add_Click({ $dlg.Close() })

    $btnRow.Children.Add($btnSave) | Out-Null
    $btnRow.Children.Add($btnCancel) | Out-Null
    $sp.Children.Add($btnRow) | Out-Null

    $dlg.ShowDialog() | Out-Null
})

# ── Start ──
$window.Add_Loaded({
    $script:myHwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
    $trackTimer.Start()
    $tbInput.Focus()
    RegisterAllHotkeys
})

$window.Add_Closing({
    SaveSettings
    [Fling.W32]::UnregisterHotKey($hkWin.Handle, $HK_SHOWHIDE) | Out-Null
    [Fling.W32]::UnregisterHotKey($hkWin.Handle, $HK_QUICKPASTE) | Out-Null
    $trackTimer.Stop()
    $sendTimer.Stop()
    $seqTimer.Stop()
})

$app = New-Object System.Windows.Application
$app.ShutdownMode = 'OnExplicitShutdown'
$window.Add_Closed({ $app.Shutdown() })
$app.Run($window) | Out-Null
