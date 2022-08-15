@echo off
if exist "%SystemRoot%\SysWOW64" path %path%;%windir%\SysNative;%SystemRoot%\SysWOW64;%~dp0
bcdedit >nul
if '%errorlevel%' NEQ '0' (goto UACPrompt) else (goto UACAdmin)
:UACPrompt
mshta vbscript:createobject("shell.application").shellexecute("""%~0""","::",,"runas",1)(window.close)&exit
exit /B
:UACAdmin
@echo ????????

#??Powershell
cd %~dp0
if not exist main.ps1 (
	echo ฆฤ????????งน?? PallasBot ??????????????????
	pause
	goto :EOF
)
setlocal enabledelayedexpansion
set POWERSHELL_EXEC=powershell
!POWERSHELL_EXEC! -NoLogo -NoProfile -Command exit
if errorlevel 1 (
    set POWERSHELL_EXEC=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
	!POWERSHELL_EXEC! -NoLogo -NoProfile -Command exit
    if errorlevel 1 (
        echo ??????????powershell?????????????????pwsh
        set POWERSHELL_EXEC=pwsh
        !POWERSHELL_EXEC! -NoLogo -NoProfile -Command exit
        if errorlevel 1 (
            set POWERSHELL_EXEC=C:\Program Files\PowerShell\7\pwsh.exe
            !POWERSHELL_EXEC! -NoLogo -NoProfile -Command exit
            if errorlevel 1 (
                echo ??????pwsh???? https://aka.ms/powershell-release?tag=stable ????PowerShell 7 ???
                echo ?????????????????????????PowerShell-x.x.x-win-x64.msi?
                pause
                rundll32 url.dll,FileProtocolHandler https://aka.ms/powershell-release?tag=stable
                exit
            )
        )
    )
)


!POWERSHELL_EXEC! -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\main.ps1 -t
pause