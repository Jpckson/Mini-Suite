# extensions
images = ["jpg","jpeg","png","bmp","webp","tiff","avif","ico"]
audio  = ["mp3","wav","flac","aac","ogg","m4a"]
video  = ["mp4","mkv","avi","mov","webm","flv","m4v"]

# target formats
image_targets = ["jpg","png","webp","bmp","tiff","avif","ico"]
audio_targets = ["mp3","wav","flac","aac","ogg","m4a"]
video_targets = ["mp4","mkv","avi","mov","webm"]

# menu key name, extensions, targets
groups = [
    ("ConvertImage", images, image_targets),
    ("ConvertAudio", audio,  audio_targets),
    # video sources can convert to video or audio formats
    ("ConvertVideo", video,  video_targets + audio_targets),
]

lines = []
for menu, exts, targets in groups:
    for ext in exts:
        base = f"Software\\Classes\\SystemFileAssociations\\.{ext}\\shell\\{menu}"

        # convert menu
        lines.append(
            f'Root: HKCU; Subkey: "{base}"; ValueType: string; '
            f'ValueName: "MUIVerb"; ValueData: "Convert"; Flags: uninsdeletekey'
        )
        lines.append(
            f'Root: HKCU; Subkey: "{base}"; ValueType: string; '
            f'ValueName: "SubCommands"; ValueData: ""'
        )

        for t in targets:
            cmdkey = f"{base}\\shell\\{t}"
            lines.append(
                f'Root: HKCU; Subkey: "{cmdkey}"; ValueType: string; '
                f'ValueName: "MUIVerb"; ValueData: "to {t.upper()}"'
            )
            lines.append(
                f'Root: HKCU; Subkey: "{cmdkey}\\command"; ValueType: string; '
                f'ValueData: "wscript.exe ""{{app}}\\convert-hidden.vbs"" '
                f'{t} ""%1"" ""{{app}}"""'
            )

print("[Registry]")
print("\n".join(lines))