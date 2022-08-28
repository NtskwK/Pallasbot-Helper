<# :
:: 获取管理员权限
@echo off
if exist "%SystemRoot%\SysWOW64" path %path%;%windir%\SysNative;%SystemRoot%\SysWOW64;%~dp0
bcdedit >nul
if '%errorlevel%' NEQ '0' (goto UACPrompt) else (goto UACAdmin)
:UACPrompt
%1 start "" mshta vbscript:createobject("shell.application").shellexecute("""%~0""","::",,"runas",1)(window.close)&exit
exit /B
:UACAdmin
cd %~dp0
echo 当前运行路径是：%CD%
echo 已获取管理员权限
:: Header to create Batch/PowerShell hybrid
@echo.
@echo.
echo 本程序将会在当前文件夹安装PallasHelper以及PallasBot的必要组件
echo 请确定脚本放置于单独的文件夹！
echo 接下来将会检测计算机上是否具安装有以下必备项
echo Git ， Python ， mongodb
echo 如果没有，则本程序将会为您自动安装。（你也可以选择自己手动安装）
@echo.
echo 或者你还可以参考手动部署手册： 
@echo https://github.com/NtskwK/Pallas-Bot/blob/master/DeploymentTutorial.md
@echo.
echo Windows 10 或 WindowsServer 2016 以下的系统还需要手动安装以下内容
@echo https://support.microsoft.com/en-us/topic/update-for-universal-c-runtime-in-windows-c0514201-7fe6-95a3-b0a5-287930f3560c
@echo.
echo 如需终止本程序，请按 Ctrl + C


setlocal enabledelayedexpansion
set POWERSHELL_EXEC=powershell
set ENCODING=Default
!POWERSHELL_EXEC! -NoLogo -NoProfile -Command exit
if errorlevel 1 (
    set POWERSHELL_EXEC=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
	!POWERSHELL_EXEC! -NoLogo -NoProfile -Command exit
    if errorlevel 1 (
        echo 警告：找不到系统组件powershell，这可能代表系统已经损坏。正在使用pwsh
        set POWERSHELL_EXEC=pwsh
		set ENCODING=GBK
        !POWERSHELL_EXEC! -NoLogo -NoProfile -Command exit
        if errorlevel 1 (
            set POWERSHELL_EXEC=C:\Program Files\PowerShell\7\pwsh.exe
            !POWERSHELL_EXEC! -NoLogo -NoProfile -Command exit
            if errorlevel 1 (
                echo 错误：找不到pwsh，请访问 https://aka.ms/powershell-release?tag=stable 手动安装PowerShell 7 后重试
                echo 按任意键后将尝试打开下载页面（通常你需要下载并安装PowerShell-x.x.x-win-x64.msi）
                pause
                rundll32 url.dll,FileProtocolHandler https://aka.ms/powershell-release?tag=stable
                exit
            )
        )
    )
)

pause
setlocal
set "POWERSHELL_BAT_ARGS=%*"
if defined POWERSHELL_BAT_ARGS set "POWERSHELL_BAT_ARGS=%POWERSHELL_BAT_ARGS:"=\"%"
if %ENCODING%==Default (
	set COMMAND="cd -LiteralPath (Split-Path '%~f0'); $_ = $input; Invoke-Expression $( '$input = $_; $_ = \"\"; $args = @( &{ $args } %POWERSHELL_BAT_ARGS% );' + [String]::Join( [char]10, $( Get-Content -LiteralPath '%~f0' ) ) )"
) else (
	set COMMAND="cd -LiteralPath (Split-Path '%~f0'); $_ = $input; Invoke-Expression $( '$input = $_; $_ = \"\"; $args = @( &{ $args } %POWERSHELL_BAT_ARGS% );' + [String]::Join( [char]10, $( Get-Content -Encoding %ENCODING% -LiteralPath '%~f0' ) ) )"
)
endlocal & %POWERSHELL_EXEC% -NoLogo -NoProfile -Command %COMMAND%

:: Any batch code that gets run after your PowerShell goes here
pause
#>

$ErrorActionPreference = 'Stop'


function DebugLog($message) 
{
	$messagestr = (Out-String -InputObject $message).TrimEnd()
	$currdate = Get-Date -Format "yyyy/MM/dd HH:mm:ss K"
	"$currdate $messagestr" | Out-File -Append -FilePath ".\install.log"
}

trap 
{
	DebugLog $_
	Write-Host "安装过程中发生了错误: $_" -ForegroundColor Red
	Write-Host "这可能是异常状况，请尝试重新执行此脚本" -ForegroundColor Red
	Write-Host "如果多次尝试后仍不能解决，请将屏幕截图以及此文件夹下的日志文件install.log发送给natsukawa247@outlook.com以尝试解决问题" -ForegroundColor Red
	Write-Host "按任意键退出"
	$unused = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
	exit 1
}


Remove-Item ".\install.log" -Recurse -ErrorAction SilentlyContinue
set-ExecutionPolicy RemoteSigned

#修改自OneClickMiraiDice by w4123Suhui
DebugLog "-------------------Installer Launched----------------------"
DebugLog "Obtaining system version info"
DebugLog $PSVersionTable
$sys = Get-WmiObject Win32_OperatingSystem | Select PSComputerName, Caption, OSArchitecture, Version, BuildNumber, CSDVersion, OSLanguage, OSProductSuite, OSProductType, SerialNumber, SystemDirectory, SystemDrive, WindowsDirectory
DebugLog $sys
DebugLog "Enabling Tls1.2"
# 尝试开启Tls1.2
if (-Not [System.Net.SecurityProtocolType]::Tls12)
{
	$TLSSource = @"
		using System.Net;
		public static class SecurityProtocolTypeExtensions
		{
			public const SecurityProtocolType EnableTls12 = (SecurityProtocolType)4032;
		}
"@
	
	Add-Type -TypeDefinition $TlSSource
	
	Try
	{
		[System.Net.ServicePointManager]::SecurityProtocol = [SecurityProtocolTypeExtensions]::EnableTls12
	}
	Catch
	{
		DebugLog "Failed to enable Tls1.2"
<#
		开启失败，暂时不报错，因为当前切换到了支持Tls1.0的下载地址
		if ($PSVersionTable.PSVersion.Major -Le 2)
		{
			Write-Host "当前系统配置不支持TLS1.2，程序可能无法正常运行。请确保你正在使用Win8或者WinService2016或更高版本，并打开Windows Update安装有关.Net Framework的更新后重试。"
		}
		else
		{
			Write-Host "当前系统配置不支持TLS1.2，程序可能无法正常运行。请更新至.Net Framework 4.5或更高版本后重试。"
		}
		Write-Host "按任意键继续"
		$unused = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
#>
	}
}
else
{
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
}


$ZipURL = "https://www.7-zip.org/a/7zr.exe"
$GitURL = "https://registry.npmmirror.com/-/binary/git-for-windows/v2.37.1.windows.1/MinGit-2.37.1-32-bit.zip"
$MongodbURL = "https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-5.0.10.zip"
$PythonURL = "https://repo.huaweicloud.com/python/3.9.9/python-3.9.9.exe"

DebugLog "ZipURL: $ZipURL"
DebugLog "GitURL: $GitURL"
DebugLog "MongodbURL: $MongodbURL"
DebugLog "PythonURL: $PythonURL"

Write-Progress -Id 100 -Activity "PallasHelper安装" -Status "正在初始化安装" -PercentComplete 0
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
function DownloadFile($url, $targetFile)
{
	$uri = New-Object "System.Uri" "$url"
	$request = [System.Net.HttpWebRequest]::Create($uri)
	$request.set_Timeout(15000) #15 second timeout
	$response = $request.GetResponse()
	$totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
	$responseStream = $response.GetResponseStream()
	$targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
	$buffer = new-object byte[] 256KB
	$count = $responseStream.Read($buffer,0,$buffer.length)
	$downloadedBytes = $count
	while ($count -gt 0)
	{
		$targetStream.Write($buffer, 0, $count)
		$count = $responseStream.Read($buffer,0,$buffer.length)
		$downloadedBytes = $downloadedBytes + $count
		Write-Progress -activity "正在下载文件 '$($url.split('/') | Select -Last 1)'" -Status "已下载 ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
	}
	Write-Progress -activity "文件 '$($url.split('/') | Select -Last 1)' 下载已完成" -Status "下载已完成" -Completed
	$targetStream.Flush()
	$targetStream.Close()
	$targetStream.Dispose()
	$responseStream.Dispose()
}

#解压文件
Try 
{
	Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
	function Unzip
	{
		param([string]$zipfile, [string]$outpath)

		[System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
	}
}
Catch
{
	DebugLog "7zr.exe required"
	if (-Not (Test-Path -Path ".\7zr.exe" -PathType Leaf))
	{
		DebugLog "7zr.exe not found, downloading"
		DownloadFile $ZipURL ".\app\7zr.exe"
	}
	
	if (-Not (Test-Path -Path ".\app\7zr.exe" -PathType Leaf))
	{
		Write-Host "无法加载7zr" -ForegroundColor red
		Exit
	}
	
	function Unzip
	{
		param([string]$zipfile, [string]$outpath)

		& .\app\7zr.exe $zipfile x $outpath
	}
}

Write-Progress -Id 100 -Activity "PallasHelper安装" -Status  "正在下载Python" -PercentComplete 40
Write-Host "检测Python"
$PYTHON = ""

Try 
{
	$Command = Get-Command -Name pip -ErrorAction Stop
	$PYTHON = "python"
}
Catch {}

if ($PYTHON -eq "")
{
	Write-Host "开始下载python"
	DownloadFile $PythonURL ".\app\python-setup.exe"
	$Command = .\app\python-setup.exe /quiet TargetDir=C:\PYTHON PrependPath=1
	Try 
	{
		$Command = Get-Command -Name python -ErrorAction Stop
		$PYTHON = "python"
	}
	Catch 
	{
		Write-Host "出现了意料外的错误，请稍后尝试重新启动！" -ForegroundColor red
		Exit
	}
}
Write-Host "Python: $PYTHON" -ForegroundColor green


Write-Progress -Id 100 -Activity "PallasHelper安装" -Status "正在检查Git" -PercentComplete 60
$GIT = ""

Try 
{
	$Command = Get-Command -Name git -ErrorAction Stop
	$GIT = "git"
}
Catch {}

Try 
{
	$Command = Get-Command -Name ".\app\git\cmd\git" -ErrorAction Stop
	$GIT = ".\app\git\cmd\git"
}
Catch {}

#本地没有git就从镜像站安装
if ($GIT -eq "")
{
	DebugLog "git not found, downloading"
	DownloadFile $GitURL ".\git.zip"
	Remove-Item ".\git\" -Recurse -ErrorAction SilentlyContinue
	Unzip ".\git.zip" ".\app\git\"
	Remove-Item ".\git.zip" -ErrorAction SilentlyContinue

	Try 
	{
		$Command = Get-Command -Name ".\app\git\cmd\git" -ErrorAction Stop
		$GIT = ".\app\git\cmd\git"
	}
	Catch 
	{
		Write-Host "无法加载Git!" -ForegroundColor red
		Exit
	}
}
DebugLog "git: $GIT"

if (Test-Path -Path ".\main.ps1" -PathType Leaf)
{
	DebugLog "Already installed, aborting"
    Write-Host "当前文件夹下已经有一份Pallasbot-Helper安装"
	Exit
}

#主目录放PallasHelper，Palla-bot的仓库要建在子目录
Write-Progress -Id 100 -Activity "PallasHelper安装" -Status "正在安装PallasHelper - 初始化存储库" -PercentComplete 80

& $GIT init
& $GIT remote add origin https://gitee.com/craun/Pallasbot-Helper.git
& $GIT fetch --depth=1
& $GIT checkout master

if (-Not (Test-Path -Path ".\main.ps1" -PathType Leaf))
{
   Throw "安装过程中出现意外错误：未成功安装文件"
}

Write-Progress -Id 100 -Activity "PallasHelper安装已完成" -Status "安装已完成" -Completed

DebugLog "Installation finished"
Write-Host "安装成功!" -ForegroundColor green