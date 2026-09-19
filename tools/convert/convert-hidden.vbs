' args: <ext> <src> <appdir>
Set args = WScript.Arguments
ext    = args(0)
src    = args(1)
appdir = args(2)

Set shell = CreateObject("Wscript.Shell")
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & _
      appdir & "\convert.ps1"" " & ext & " """ & src & """ """ & appdir & """"

' 0 = hidden, False = dont wait (each file launches independently)
shell.Run cmd, 0, False