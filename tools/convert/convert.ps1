# args: <ext> <src> <appdir>
param($ext, $src, $appdir)

# loading cursor
Add-Type -AssemblyName System.Windows.Forms

$busyForm = New-Object System.Windows.Forms.Form
$busyForm.Opacity        = 0
$busyForm.ShowInTaskbar  = $false
$busyForm.FormBorderStyle = 'None'
$busyForm.Size           = New-Object System.Drawing.Size(0, 0)
$busyForm.StartPosition  = 'Manual'
$busyForm.Location       = New-Object System.Drawing.Point(-32000, -32000)
$busyForm.UseWaitCursor  = $true
$busyForm.Show()
$busyForm.Hide()
[System.Windows.Forms.Application]::DoEvents()

# throttle by core count
$max = [int]$env:NUMBER_OF_PROCESSORS
if ($max -lt 1) { $max = 1 }
$sem = New-Object System.Threading.Semaphore($max, $max, "Global\ConvertMenuSem")
$sem.WaitOne() | Out-Null

try {
    $dir  = [IO.Path]::GetDirectoryName($src)
    $name = [IO.Path]::GetFileNameWithoutExtension($src)
    $base = [IO.Path]::Combine($dir, $name)

    $dst = "$base.$ext"
    $n = 2
    while (Test-Path -LiteralPath $dst) {
        $dst = "$base converted $n.$ext"
        $n++
    }

    & "$appdir\ffmpeg.exe" -y -i $src $dst 2>$null
    $code = $LASTEXITCODE

    if ($code -ne 0) {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Conversion failed for:`n$src",
            "Convert Menu", "OK", "Error") | Out-Null
    }
}
finally {
    # remove busy indicator
    $sem.Release() | Out-Null
    $busyForm.Dispose()
}