# ── Fling — Floating Input Sender ─────────────────────
# Write once, send anywhere.
# Ctrl+` : global hotkey (show/hide)
# Enter  : send to last active window
# Shift+Enter : newline
# Drag .md/.txt : insert content or path
# ───────────────────────────────────────────────────────

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

function SendCtrlV {
    $KEYDOWN = [uint32]0; $KEYUP = [uint32]2; $zero = [UIntPtr]::Zero
    [Fling.W32]::keybd_event(0x11, 0, $KEYDOWN, $zero)
    [Fling.W32]::keybd_event(0x56, 0, $KEYDOWN, $zero)
    [Fling.W32]::keybd_event(0x56, 0, $KEYUP, $zero)
    [Fling.W32]::keybd_event(0x11, 0, $KEYUP, $zero)
}

function SendEnterKey {
    $KEYDOWN = [uint32]0; $KEYUP = [uint32]2; $zero = [UIntPtr]::Zero
    [Fling.W32]::keybd_event(0x0D, 0, $KEYDOWN, $zero)
    [Fling.W32]::keybd_event(0x0D, 0, $KEYUP, $zero)
}

function GetTargetHint([IntPtr]$hwnd) {
    if ($hwnd -eq [IntPtr]::Zero) { return '' }
    # Process name
    [uint32]$hintPid = 0
    [Fling.W32]::GetWindowThreadProcessId($hwnd, [ref]$hintPid) | Out-Null
    $procName = ''
    try {
        $proc = [System.Diagnostics.Process]::GetProcessById([int]$hintPid)
        $procName = $proc.ProcessName
    } catch {}
    # Window title
    $sb = New-Object System.Text.StringBuilder 256
    [Fling.W32]::GetWindowText($hwnd, $sb, 256) | Out-Null
    $title = $sb.ToString()
    # Shorten title
    if ($title.Length -gt 40) { $title = $title.Substring(0, 37) + '...' }
    if ($title) {
        return "$procName  ($title)"
    }
    return $procName
}

# ── Settings file ──
$settingsPath = Join-Path $PSScriptRoot 'fling-settings.json'
$defaults = @{
    x = 200; y = 840; w = 720; h = 160
    topMost = $true
    clearAfterSend = $true
    autoEnter = $true
    pathOnly = $false
    hotkey = 'Ctrl+Oem3'
    hkToggleClear = ''
    hkToggleEnter = ''
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

function SaveSettings {
    $s = @{
        x = $form.Location.X; y = $form.Location.Y
        w = $form.Size.Width;  h = $form.Size.Height
        topMost = $form.TopMost
        clearAfterSend = $chkClear.Checked
        autoEnter = $chkEnter.Checked
        pathOnly = $chkPath.Checked
        hotkey = $script:hotkeyName
        hkToggleClear = $settings.hkToggleClear
        hkToggleEnter = $settings.hkToggleEnter
    }
    $s | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8
}

$settings = LoadSettings

# ── State ──
$script:targetHwnd  = [IntPtr]::Zero
$script:formHwnd    = [IntPtr]::Zero
$script:sendStep    = 'idle'
$script:oldClipText = $null
$script:hotkeyName  = $settings.hotkey

# ── Colors ──
$bgDark    = [System.Drawing.Color]::FromArgb(30, 30, 46)
$bgInput   = [System.Drawing.Color]::FromArgb(24, 24, 37)
$fgText    = [System.Drawing.Color]::FromArgb(205, 214, 244)
$fgDim     = [System.Drawing.Color]::FromArgb(100, 100, 120)
$accent    = [System.Drawing.Color]::FromArgb(16, 185, 129)
$btnOff    = [System.Drawing.Color]::FromArgb(45, 45, 65)
$btnOffTxt = [System.Drawing.Color]::FromArgb(120, 120, 140)

# ── Toggle button helper ──
function MakeToggle($text, $checked, $x) {
    $btn = New-Object System.Windows.Forms.CheckBox
    $btn.Text       = $text
    $btn.Appearance = 'Button'
    $btn.FlatStyle  = 'Flat'
    $btn.Font       = New-Object System.Drawing.Font('Segoe UI', 8)
    $btn.Height     = 24
    $btn.AutoSize   = $true
    $btn.Location   = New-Object System.Drawing.Point($x, 2)
    $btn.Checked    = $checked
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = $btnOff
    $btn.FlatAppearance.CheckedBackColor    = $accent
    $btn.FlatAppearance.MouseOverBackColor  = $accent
    $btn.FlatAppearance.MouseDownBackColor  = $accent

    if ($checked) {
        $btn.BackColor = $accent; $btn.ForeColor = [System.Drawing.Color]::White
    } else {
        $btn.BackColor = $btnOff; $btn.ForeColor = $btnOffTxt
        $btn.FlatAppearance.MouseOverBackColor  = $btnOff
        $btn.FlatAppearance.MouseDownBackColor  = $btnOff
    }

    $btn.Add_CheckedChanged({
        param($s, $ev)
        if ($s.Checked) {
            $s.BackColor = $accent; $s.ForeColor = [System.Drawing.Color]::White
            $s.FlatAppearance.CheckedBackColor    = $accent
            $s.FlatAppearance.MouseOverBackColor  = $accent
            $s.FlatAppearance.MouseDownBackColor  = $accent
        } else {
            $s.BackColor = $btnOff; $s.ForeColor = $btnOffTxt
            $s.FlatAppearance.CheckedBackColor    = $btnOff
            $s.FlatAppearance.MouseOverBackColor  = $btnOff
            $s.FlatAppearance.MouseDownBackColor  = $btnOff
        }
    })

    return $btn
}

# ── Form ──
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Fling"
$form.TopMost         = $settings.topMost
$form.Opacity         = 0.95
$form.Size            = New-Object System.Drawing.Size($settings.w, $settings.h)
$form.MinimumSize     = New-Object System.Drawing.Size(400, 110)
$form.StartPosition   = 'Manual'
$form.Location        = New-Object System.Drawing.Point($settings.x, $settings.y)
$form.BackColor       = $bgDark
$form.FormBorderStyle = 'SizableToolWindow'
$form.ShowInTaskbar   = $false

# ── Bottom options ──
$optPanel = New-Object System.Windows.Forms.Panel
$optPanel.Dock      = 'Bottom'
$optPanel.Height    = 30
$optPanel.BackColor = $bgDark

$chkClear  = MakeToggle 'Clear after send' $settings.clearAfterSend 4
$chkEnter  = MakeToggle 'Auto Enter' $settings.autoEnter 120
$chkPath   = MakeToggle 'File: path only' $settings.pathOnly 220
$chkOnTop  = MakeToggle 'Always on top' $settings.topMost 330

$chkOnTop.Add_CheckedChanged({
    param($s, $ev)
    $form.TopMost = $s.Checked
})

# Gear button
$btnGear = New-Object System.Windows.Forms.Button
$btnGear.Text      = [char]0x2699
$btnGear.Font      = New-Object System.Drawing.Font('Segoe UI', 11)
$btnGear.Size      = New-Object System.Drawing.Size(28, 24)
$btnGear.FlatStyle = 'Flat'
$btnGear.BackColor = $bgDark
$btnGear.ForeColor = $fgDim
$btnGear.Anchor    = 'Right'
$btnGear.FlatAppearance.BorderSize = 0
$btnGear.FlatAppearance.MouseOverBackColor = $btnOff
$btnGear.FlatAppearance.MouseDownBackColor = $btnOff
$btnGear.Cursor    = [System.Windows.Forms.Cursors]::Hand

$btnGear.Add_Click({ ShowSettings })

$optPanel.Controls.AddRange(@($chkClear, $chkEnter, $chkPath, $chkOnTop, $btnGear))

# Reposition gear to right edge on resize
$optPanel.Add_Resize({
    $btnGear.Location = New-Object System.Drawing.Point(($optPanel.Width - 34), 2)
})

# ── Settings dialog ──
function ShowSettings {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text            = 'Fling Settings'
    $dlg.Size            = New-Object System.Drawing.Size(400, 280)
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.StartPosition   = 'CenterParent'
    $dlg.MaximizeBox     = $false
    $dlg.MinimizeBox     = $false
    $dlg.BackColor       = $bgDark
    $dlg.TopMost         = $true

    $dlgFont     = New-Object System.Drawing.Font('Segoe UI', 10)
    $dlgFontSm   = New-Object System.Drawing.Font('Segoe UI', 9)
    $hkBg        = [System.Drawing.Color]::FromArgb(40, 40, 60)

    # Hotkey definitions: label, settings key, current value
    $hotkeyDefs = @(
        @{ label = 'Show / Hide';       key = 'hotkey';           current = $script:hotkeyName }
        @{ label = 'Toggle Clear';      key = 'hkToggleClear';    current = if ($settings.hkToggleClear) { $settings.hkToggleClear } else { '' } }
        @{ label = 'Toggle Auto Enter'; key = 'hkToggleEnter';    current = if ($settings.hkToggleEnter) { $settings.hkToggleEnter } else { '' } }
    )

    $hkFields = @{}
    $yPos = 15
    foreach ($def in $hotkeyDefs) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text      = $def.label
        $lbl.Location  = New-Object System.Drawing.Point(20, ($yPos + 3))
        $lbl.AutoSize  = $true
        $lbl.ForeColor = $fgText
        $lbl.Font      = $dlgFont
        $dlg.Controls.Add($lbl)

        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Location  = New-Object System.Drawing.Point(180, $yPos)
        $tb.Size      = New-Object System.Drawing.Size(150, 28)
        $tb.ReadOnly  = $true
        $tb.Text      = $def.current
        $tb.Font      = $dlgFontSm
        $tb.BackColor = $hkBg
        $tb.ForeColor = $accent
        $tb.TextAlign = 'Center'
        $tb.Tag       = $def.key
        $tb.Cursor    = [System.Windows.Forms.Cursors]::Hand

        # Click to capture
        $tb.Add_Enter({
            param($s, $ev)
            $s.Text = 'Press keys...'
            $s.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 50)
        })

        $tb.Add_KeyDown({
            param($s, $e)
            $e.SuppressKeyPress = $true
            $parts = @()
            if ($e.Control) { $parts += 'Ctrl' }
            if ($e.Alt)     { $parts += 'Alt' }
            if ($e.Shift)   { $parts += 'Shift' }
            $keyName = $e.KeyCode.ToString()
            # Skip lone modifiers
            if ($keyName -in @('ControlKey','ShiftKey','Menu')) { return }
            $parts += $keyName
            $s.Text = ($parts -join '+')
            $s.ForeColor = $accent
            # Move focus away
            $dlg.ActiveControl = $null
        })

        # Right-click to clear
        $tb.Add_MouseDown({
            param($s, $e)
            if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
                $s.Text = ''
                $s.ForeColor = $accent
            }
        })

        $dlg.Controls.Add($tb)
        $hkFields[$def.key] = $tb
        $yPos += 40
    }

    # Hint
    $hintLbl = New-Object System.Windows.Forms.Label
    $hintLbl.Text      = 'Click field + press keys  |  Right-click to clear'
    $hintLbl.Location  = New-Object System.Drawing.Point(20, ($yPos + 5))
    $hintLbl.AutoSize  = $true
    $hintLbl.ForeColor = $fgDim
    $hintLbl.Font      = New-Object System.Drawing.Font('Segoe UI', 8)
    $dlg.Controls.Add($hintLbl)

    # Save button
    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text      = 'Save'
    $btnSave.Size      = New-Object System.Drawing.Size(80, 30)
    $btnSave.Location  = New-Object System.Drawing.Point(200, ($yPos + 35))
    $btnSave.FlatStyle = 'Flat'
    $btnSave.BackColor = $accent
    $btnSave.ForeColor = [System.Drawing.Color]::White
    $btnSave.Font      = $dlgFontSm
    $btnSave.FlatAppearance.BorderSize = 0

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text      = 'Cancel'
    $btnCancel.Size      = New-Object System.Drawing.Size(80, 30)
    $btnCancel.Location  = New-Object System.Drawing.Point(290, ($yPos + 35))
    $btnCancel.FlatStyle = 'Flat'
    $btnCancel.BackColor = $btnOff
    $btnCancel.ForeColor = $btnOffTxt
    $btnCancel.Font      = $dlgFontSm
    $btnCancel.FlatAppearance.BorderSize = 0

    $btnSave.Add_Click({
        # Update hotkey name
        $script:hotkeyName = $hkFields['hotkey'].Text
        $settings.hkToggleClear = $hkFields['hkToggleClear'].Text
        $settings.hkToggleEnter = $hkFields['hkToggleEnter'].Text

        RegisterAllHotkeys
        SaveSettings
        $dlg.Close()
    })

    $btnCancel.Add_Click({ $dlg.Close() })

    $dlg.Controls.AddRange(@($btnSave, $btnCancel))
    $dlg.ShowDialog($form) | Out-Null
}

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

# ── Top status ──
$label = New-Object System.Windows.Forms.Label
$label.Text      = "Ctrl+``  show/hide  |  Enter  send  |  Shift+Enter  newline  |  Drop .md .txt"
$label.Dock      = 'Top'
$label.Height    = 20
$label.ForeColor = $fgDim
$label.BackColor = $bgDark
$label.Font      = New-Object System.Drawing.Font('Segoe UI', 8.5)
$label.Padding   = New-Object System.Windows.Forms.Padding(8, 3, 0, 0)

# ── Text input (WinForms RichTextBox = native IME support) ──
$textBox = New-Object System.Windows.Forms.RichTextBox
$textBox.Dock             = 'Fill'
$textBox.Font             = New-Object System.Drawing.Font('Segoe UI', 13)
$textBox.BackColor        = $bgInput
$textBox.ForeColor        = $fgText
$textBox.BorderStyle      = 'None'
$textBox.ScrollBars       = 'Vertical'
$textBox.AcceptsTab       = $false
$textBox.DetectUrls       = $false
$textBox.ShortcutsEnabled = $true
$textBox.AllowDrop        = $true
$textBox.EnableAutoDragDrop = $false

$form.Controls.Add($textBox)
$form.Controls.Add($label)
$form.Controls.Add($optPanel)

# ── File drag & drop ──
$textBox.Add_DragEnter({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $files = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
        $validExts = @('.md', '.txt')
        $hasValid = $false
        foreach ($f in $files) {
            if ($validExts -contains [System.IO.Path]::GetExtension($f).ToLower()) {
                $hasValid = $true; break
            }
        }
        if ($hasValid) {
            $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
        } else {
            $e.Effect = [System.Windows.Forms.DragDropEffects]::None
        }
    }
})

$textBox.Add_DragDrop({
    param($sender, $e)
    $files = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    $validExts = @('.md', '.txt')
    foreach ($f in $files) {
        $ext = [System.IO.Path]::GetExtension($f).ToLower()
        if ($validExts -contains $ext) {
            $fileName = [System.IO.Path]::GetFileName($f)
            if ($chkPath.Checked) {
                $insert = $f
            } else {
                $content = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
                $insert = "[$fileName]`r`n$content"
            }
            $pos = $textBox.SelectionStart
            $textBox.Text = $textBox.Text.Insert($pos, $insert)
            $textBox.SelectionStart = $pos + $insert.Length
        }
    }
    $textBox.Focus()
})

# ── Target window tracking (200ms poll) ──
$trackTimer = New-Object System.Windows.Forms.Timer
$trackTimer.Interval = 200
$trackTimer.Add_Tick({
    $hwnd = [Fling.W32]::GetForegroundWindow()
    if ($hwnd -ne [IntPtr]::Zero -and $hwnd -ne $script:formHwnd) {
        $script:targetHwnd = $hwnd
        $hint = GetTargetHint $hwnd
        $label.Text = "-> $hint"
    }
})

# ── Send timer (async paste + enter + refocus) ──
$sendTimer = New-Object System.Windows.Forms.Timer
$sendTimer.Interval = 150
$sendTimer.Add_Tick({
    $sendTimer.Stop()
    switch ($script:sendStep) {
        'paste' {
            SendCtrlV
            if ($chkEnter.Checked) {
                $script:sendStep = 'enter'
                $sendTimer.Interval = 250
                $sendTimer.Start()
            } else {
                $script:sendStep = 'refocus'
                $sendTimer.Interval = 40
                $sendTimer.Start()
            }
        }
        'enter' {
            SendEnterKey
            $script:sendStep = 'refocus'
            $sendTimer.Interval = 40
            $sendTimer.Start()
        }
        'refocus' {
            if ($script:oldClipText) {
                try { [System.Windows.Forms.Clipboard]::SetText($script:oldClipText) } catch {}
                $script:oldClipText = $null
            }
            $form.Activate()
            $textBox.Focus()
            $script:sendStep = 'idle'
            $sendTimer.Interval = 150
        }
    }
})

# ── Send function ──
function DoSend {
    $text = $textBox.Text.TrimEnd("`r", "`n")
    if ([string]::IsNullOrWhiteSpace($text)) {
        $textBox.Clear()
        return
    }
    if ($script:sendStep -ne 'idle') { return }

    # Clipboard backup
    $script:oldClipText = $null
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $script:oldClipText = [System.Windows.Forms.Clipboard]::GetText()
    }
    [System.Windows.Forms.Clipboard]::SetText($text)

    if ($chkClear.Checked) {
        # SelectAll + Delete = undoable (Ctrl+Z)
        $textBox.SelectAll()
        $textBox.SelectedText = ''
    } else {
        # Remove trailing newline from Enter key
        $textBox.Text = $text
        $textBox.SelectionStart = $textBox.Text.Length
    }

    if ($script:targetHwnd -ne [IntPtr]::Zero) {
        ForceForeground $script:targetHwnd
        $script:sendStep = 'paste'
        $sendTimer.Start()
    }
}

# ── Key events ──
$textBox.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Return -and -not $e.Shift) {
        $e.SuppressKeyPress = $true
    }
})
$textBox.Add_KeyUp({
    param($sender, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Return -and -not $e.Shift) {
        DoSend
    }
})

# ── Global hotkey (Ctrl+`) ──
$HK_SHOWHIDE     = 9001
$HK_TOGGLE_CLEAR = 9002
$HK_TOGGLE_ENTER = 9003

# Custom WndProc to catch WM_HOTKEY
$hotkeyForm = New-Object System.Windows.Forms.Form
$hotkeyForm.ShowInTaskbar = $false
$hotkeyForm.WindowState = 'Minimized'
$hotkeyForm.FormBorderStyle = 'None'
$hotkeyForm.Size = New-Object System.Drawing.Size(0, 0)
$hotkeyForm.Opacity = 0

$hotkeyTimer = New-Object System.Windows.Forms.Timer
$hotkeyTimer.Interval = 50
$hotkeyTimer.Add_Tick({
    # Poll approach for hotkey: check if hotkey message is pending
    # (RegisterHotKey posts WM_HOTKEY to the registering thread's message queue)
})

# Use a NativeWindow subclass for WM_HOTKEY
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
    switch ($hkWin.LastHotkeyId) {
        $HK_SHOWHIDE {
            if ($form.Visible -and $form.ContainsFocus) {
                $form.Hide()
            } else {
                $form.Show()
                $form.Activate()
                $textBox.Focus()
            }
        }
        $HK_TOGGLE_CLEAR {
            $chkClear.Checked = -not $chkClear.Checked
        }
        $HK_TOGGLE_ENTER {
            $chkEnter.Checked = -not $chkEnter.Checked
        }
    }
})

function RegisterAllHotkeys {
    # Unregister all first
    [Fling.W32]::UnregisterHotKey($hkWin.Handle, $HK_SHOWHIDE) | Out-Null
    [Fling.W32]::UnregisterHotKey($hkWin.Handle, $HK_TOGGLE_CLEAR) | Out-Null
    [Fling.W32]::UnregisterHotKey($hkWin.Handle, $HK_TOGGLE_ENTER) | Out-Null

    # Show/Hide
    $p = ParseHotkey $script:hotkeyName
    if ($p) { [Fling.W32]::RegisterHotKey($hkWin.Handle, $HK_SHOWHIDE, $p.mod, $p.vk) | Out-Null }

    # Toggle Clear
    $p = ParseHotkey $settings.hkToggleClear
    if ($p) { [Fling.W32]::RegisterHotKey($hkWin.Handle, $HK_TOGGLE_CLEAR, $p.mod, $p.vk) | Out-Null }

    # Toggle Auto Enter
    $p = ParseHotkey $settings.hkToggleEnter
    if ($p) { [Fling.W32]::RegisterHotKey($hkWin.Handle, $HK_TOGGLE_ENTER, $p.mod, $p.vk) | Out-Null }
}

# ── Start ──
$form.Add_Shown({
    $script:formHwnd = $form.Handle
    $trackTimer.Start()
    $textBox.Focus()
    RegisterAllHotkeys
})

$form.Add_FormClosing({
    SaveSettings
    [Fling.W32]::UnregisterHotKey($hkWin.Handle, $HK_SHOWHIDE) | Out-Null
    [Fling.W32]::UnregisterHotKey($hkWin.Handle, $HK_TOGGLE_CLEAR) | Out-Null
    [Fling.W32]::UnregisterHotKey($hkWin.Handle, $HK_TOGGLE_ENTER) | Out-Null
    $trackTimer.Stop()
    $sendTimer.Stop()
})

[System.Windows.Forms.Application]::Run($form)
