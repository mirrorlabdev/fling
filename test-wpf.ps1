Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="WPF IME + Emoji Test" Width="500" Height="150"
        Topmost="True" WindowStyle="ToolWindow"
        Background="#1e1e2e">
    <TextBox Name="tb" FontSize="16" FontFamily="Segoe UI"
             Background="#181825" Foreground="#cdd6f4"
             AcceptsReturn="True" TextWrapping="Wrap"
             VerticalScrollBarVisibility="Auto"
             Margin="8" BorderThickness="0"
             CaretBrush="#10b981" />
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)
$window.ShowDialog() | Out-Null
