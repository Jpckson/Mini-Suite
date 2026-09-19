# extensions
images = ["jpg","jpeg","png","webp","avif"]
audio  = ["mp3","aac","ogg","m4a"]
video  = ["mp4","mkv","mov","webm","flv","m4v"]

all_exts = images + audio + video

# key name, label, arg passed to the vbs
quality_levels = [
    ("lossless", "Lossless",     "lossless"),
    ("q90",      "90% Quality",  "90"),
    ("q75",      "75% Quality",  "75"),
    ("q50",      "50% Quality",  "50"),
]

lines = []
for ext in all_exts:
    base = f"Software\\Classes\\SystemFileAssociations\\.{ext}\\shell\\CompressFile"

    # Parent "Compress" submenu
    lines.append(
        f'Root: HKCU; Subkey: "{base}"; ValueType: string; '
        f'ValueName: "MUIVerb"; ValueData: "Compress"; Flags: uninsdeletekey'
    )
    lines.append(
        f'Root: HKCU; Subkey: "{base}"; ValueType: string; '
        f'ValueName: "SubCommands"; ValueData: ""'
    )

    for key, label, arg in quality_levels:
        cmdkey = f"{base}\\shell\\{key}"
        lines.append(
            f'Root: HKCU; Subkey: "{cmdkey}"; ValueType: string; '
            f'ValueName: "MUIVerb"; ValueData: "{label}"'
        )
        lines.append(
            f'Root: HKCU; Subkey: "{cmdkey}\\command"; ValueType: string; '
            f'ValueData: "wscript.exe ""{{app}}\\compress-hidden.vbs"" '
            f'{arg} ""%1"" ""{{app}}"""'
        )

print("[Registry]")
print("\n".join(lines))