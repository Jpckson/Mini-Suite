' args: <quality> <src> <appdir>
Set args = WScript.Arguments
quality = args(0)
src     = args(1)
appdir  = args(2)

Set shell = CreateObject("Wscript.Shell")
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & _
      appdir & "\compress.ps1"" " & quality & " """ & src & """ """ & appdir & """"

' 0 = hidden, False = dont wait (each file launches independently)
shell.Run cmd, 0, False