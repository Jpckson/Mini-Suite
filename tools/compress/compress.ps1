# args: <quality> <src> <appdir>
param($quality, $src, $appdir)

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
$sem = New-Object System.Threading.Semaphore($max, $max, "Global\CompressMenuSem")
$sem.WaitOne() | Out-Null

try {
    $dir  = [IO.Path]::GetDirectoryName($src)
    $name = [IO.Path]::GetFileNameWithoutExtension($src)
    $ext  = [IO.Path]::GetExtension($src).TrimStart('.').ToLower()
    $base = [IO.Path]::Combine($dir, $name)

    # same ext as src
    $dst = "$base compressed.$ext"
    $n = 2
    while (Test-Path -LiteralPath $dst) {
        $dst = "$base compressed $n.$ext"
        $n++
    }

    # pngquant instead of ffmpeg for pngs
    if ($ext -eq "png") {
        $pngArgs = @()
        switch ($quality) {
            "lossless" { $pngArgs += @("--quality", "95-100") }
            "90"       { $pngArgs += @("--quality", "80-95") }
            "75"       { $pngArgs += @("--quality", "65-85") }
            "50"       { $pngArgs += @("--quality", "40-70") }
        }

        # 1 = slowest, 11 = fastest
        $pngArgs += @("--speed", "1", "--strip", "--force", "--output", $dst, "--", $src)

        & "$appdir\pngquant.exe" @pngArgs 2>$null
        $code = $LASTEXITCODE

        # pngquant exit 99: cant meet minimum quality. retry without a floor so user gets a file
        if ($code -eq 99) {
            $retry = @()
            switch ($quality) {
                "lossless" { $retry += @("--quality", "0-100") }
                "90"       { $retry += @("--quality", "0-95") }
                "75"       { $retry += @("--quality", "0-85") }
                "50"       { $retry += @("--quality", "0-70") }
            }
            $retry += @("--speed", "1", "--strip", "--force", "--output", $dst, "--", $src)
            & "$appdir\pngquant.exe" @retry 2>$null
            $code = $LASTEXITCODE
        }
    }
    # ffmpeg
    else {
        # map quality
        $args = @("-y", "-i", $src)

        switch ($ext) {
            # jpeg: 2 = best, 31 = worst
            { $_ -in @("jpg", "jpeg") } {
                switch ($quality) {
                    "lossless" { $args += @("-q:v", "1") }
                    "90"       { $args += @("-q:v", "3") }
                    "75"       { $args += @("-q:v", "7") }
                    "50"       { $args += @("-q:v", "13") }
                }
            }
            # webp: 0 = worst, 100 = best
            "webp" {
                switch ($quality) {
                    "lossless" { $args += @("-lossless", "1") }
                    "90"       { $args += @("-quality", "90") }
                    "75"       { $args += @("-quality", "75") }
                    "50"       { $args += @("-quality", "50") }
                }
            }
            # avif: 0 = best, 63 = worst
            "avif" {
                switch ($quality) {
                    "lossless" { $args += @("-crf", "0") }
                    "90"       { $args += @("-crf", "18") }
                    "75"       { $args += @("-crf", "28") }
                    "50"       { $args += @("-crf", "40") }
                }
            }
            # mp4/mov/mkv(h.264): 0 = best, 51 = worst.
            # copy audio for lossless and 90, re-encode below
            { $_ -in @("mp4", "mov", "mkv", "m4v") } {
                switch ($quality) {
                    "lossless" { $args += @("-c:v", "libx264", "-crf", "0",  "-c:a", "copy") }
                    "90"       { $args += @("-c:v", "libx264", "-crf", "20", "-c:a", "copy") }
                    "75"       { $args += @("-c:v", "libx264", "-crf", "26", "-c:a", "aac", "-b:a", "192k") }
                    "50"       { $args += @("-c:v", "libx264", "-crf", "32", "-c:a", "aac", "-b:a", "128k") }
                }
            }
            # webm: copy at lossless, else opus
            # copy audio for lossless and 90, re-encode below
            "webm" {
                switch ($quality) {
                    "lossless" { $args += @("-c:v", "libvpx-vp9", "-lossless", "1", "-c:a", "copy") }
                    "90"       { $args += @("-c:v", "libvpx-vp9", "-crf", "24", "-b:v", "0", "-c:a", "copy") }
                    "75"       { $args += @("-c:v", "libvpx-vp9", "-crf", "31", "-b:v", "0", "-c:a", "libopus", "-b:a", "192k") }
                    "50"       { $args += @("-c:v", "libvpx-vp9", "-crf", "37", "-b:v", "0", "-c:a", "libopus", "-b:a", "128k") }
                }
            }
            # flv video (older H.264 container).
            "flv" {
                switch ($quality) {
                    "lossless" { $args += @("-c:v", "libx264", "-crf", "0",  "-c:a", "copy") }
                    "90"       { $args += @("-c:v", "libx264", "-crf", "20", "-c:a", "copy") }
                    "75"       { $args += @("-c:v", "libx264", "-crf", "26", "-c:a", "aac", "-b:a", "192k") }
                    "50"       { $args += @("-c:v", "libx264", "-crf", "32", "-c:a", "aac", "-b:a", "128k") }
                }
            }
            # mp3: 0 = best, 9 = worst
            "mp3" {
                switch ($quality) {
                    "lossless" { $args += @("-q:a", "0") }
                    "90"       { $args += @("-q:a", "2") }
                    "75"       { $args += @("-q:a", "4") }
                    "50"       { $args += @("-q:a", "6") }
                }
            }
            # aac/m4a
            { $_ -in @("aac", "m4a") } {
                switch ($quality) {
                    "lossless" { $args += @("-c:a", "aac", "-b:a", "320k") }
                    "90"       { $args += @("-c:a", "aac", "-b:a", "256k") }
                    "75"       { $args += @("-c:a", "aac", "-b:a", "192k") }
                    "50"       { $args += @("-c:a", "aac", "-b:a", "128k") }
                }
            }
            # ogg
            "ogg" {
                switch ($quality) {
                    "lossless" { $args += @("-c:a", "copy") }
                    "90"       { $args += @("-c:a", "libvorbis", "-q:a", "6") }
                    "75"       { $args += @("-c:a", "libvorbis", "-q:a", "4") }
                    "50"       { $args += @("-c:a", "libvorbis", "-q:a", "2") }
                }
            }
            # opus
            "opus" {
                switch ($quality) {
                    "lossless" { $args += @("-c:a", "copy") }
                    "90"       { $args += @("-c:a", "libopus", "-b:a", "256k") }
                    "75"       { $args += @("-c:a", "libopus", "-b:a", "192k") }
                    "50"       { $args += @("-c:a", "libopus", "-b:a", "128k") }
                }
            }
            # flac: already lossless. degrade to 16-bit, then lower sample rate.
            "flac" {
                switch ($quality) {
                    "lossless" { $args += @("-c:a", "flac", "-compression_level", "12") }
                    "90"       { $args += @("-c:a", "flac", "-compression_level", "12", "-sample_fmt", "s16") }
                    "75"       { $args += @("-c:a", "flac", "-compression_level", "12", "-sample_fmt", "s16", "-ar", "44100") }
                    "50"       { $args += @("-c:a", "flac", "-compression_level", "12", "-sample_fmt", "s16", "-ar", "22050") }
                }
            }
            # wav: already lossless. degrade to 16-bit, then lower sample rate.
            "wav" {
                switch ($quality) {
                    "lossless" { $args += @("-c:a", "copy") }
                    "90"       { $args += @("-c:a", "pcm_s16le") }
                    "75"       { $args += @("-c:a", "pcm_s16le", "-ar", "44100") }
                    "50"       { $args += @("-c:a", "pcm_s16le", "-ar", "22050") }
                }
            }
            # fallback
            default {
                switch ($quality) {
                    "lossless" { $args += @("-q:v", "1") }
                    "90"       { $args += @("-q:v", "3") }
                    "75"       { $args += @("-q:v", "7") }
                    "50"       { $args += @("-q:v", "13") }
                }
            }
        }

        $args += $dst

        & "$appdir\ffmpeg.exe" @args 2>$null
        $code = $LASTEXITCODE
    }

    if ($code -ne 0) {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Compression failed for:`n$src",
            "Compress Menu", "OK", "Error") | Out-Null
    }
}
finally {
    # remove loading cursor
    $sem.Release() | Out-Null
    $busyForm.Dispose()
}