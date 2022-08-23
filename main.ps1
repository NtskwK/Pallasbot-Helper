If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
{  
	$arguments ="& '" + $myinvocation.mycommand.definition +"'"+"$args[0]"
	Start-Process powershell -Verb runAs -ArgumentList $arguments 
	exit
}


$Host.UI.RawUI.WindowTitle = 'PallasHelper'

Write-Host "欢迎使用PallasBotHelper"
Write-Host "正在检测 PallasBoty 和 Pallas-Bot 必须的依赖项"

$PythonURL = "https://repo.huaweicloud.com/python/3.9.9/python-3.9.9.exe"
$GitURL = "https://repo.huaweicloud.com/git-for-windows/v2.37.1.windows.1/MinGit-2.37.1-32-bit.zip"
$MongodbURL = "https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-6.0.0-signed.msi"
$CppURL = "https://myvs.download.prss.microsoft.com/dbazure/mu_visual_cpp_build_tools_2015_update_3_x64_dvd_dfd9a39c.iso?t=2d9c8bc8-eb35-4d1f-a0e2-962fc2463acc'&'e=1660583046'&'h=95cab42736b0cd8ed7679c6ee95d6b00c939abf58473188a97e3cc339535f81b'&'su=1"
$FfmpegURL = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full.7z"
$ZipURL = "https://www.7-zip.org/a/7zr.exe"

$PYTHON = ""
$GIT = ""
$FFMPEG = ""
$7ZR = ""

$DB = 0

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
<#
		开启失败，暂时不报错，因为当前切换到了支持Tls1.0的下载地址
		if ($PSVersionTable.PSVersion.Major -Le 2)
		{
			Write-Host "当前系统配置不支持TLS1.2，程序可能无法正常运行。请确保你正在使用Win7SP1或者Win2008R2SP1或更高版本，并打开Windows Update安装有关.Net Framework的更新后重试。"
		}
		else
		{
			Write-Host "当前系统配置不支持TLS1.2，程序可能无法正常运行。请更新至.Net Framework 4.5或更高版本后重试。"
		}
		Read-Host -Prompt "按回车键继续执行，但程序可能无法正常运行 ----->" 
#>
	}
}
else
{
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
}

#低版本PowerShell手动获取路径
if (!$PSScriptRoot)
{
	$PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

cd -LiteralPath "$PSScriptRoot"

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

Write-Host "PallasBot启动脚本"
Write-Host "初始化"

#检查安装
if (-Not (Test-Path -LiteralPath "$PSScriptRoot\nonebotPallas\.git" -PathType Container))
{
	Write-Host "警告：.git文件夹不存在" -ForegroundColor red
	Write-Host "这可能代表你之前可能没没有按照特定的方式安装" -ForegroundColor red
	Write-Host "虽然PallasBot仍将正常工作，但PallasInstaller将无法正常使用" -ForegroundColor red
	Write-Host "你可以通过尝试使用脚本重新安装以解决此问题" -ForegroundColor red
}

#解压文件
Try 
{
	Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
	function Unzip
	{
		param([string]$zipfile, [string]$outpath)
		Try{
			[System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
		}Catch{
			if (-Not (Test-Path -Path "$PSScriptRoot\app\7zr.exe" -PathType Leaf))
			{
				Write-Host "正在下载7zr"
				DownloadFile $ZipURL "$PSScriptRoot\app\7zr.exe"
			}
			
			if (-Not (Test-Path -Path "$PSScriptRoot\app\7zr.exe" -PathType Leaf))
			{
				Write-Host "无法加载7zr" -ForegroundColor red
				Exit
			}
			
			$7ZR = "$PSScriptRoot\app\7zr.exe"
		
			& $7ZR x $zipfile -o"$outpath"
			
		}

	}
}
Catch
{
	Write-Host "出现了未知的异常"
}


Write-Host "检测Python"
Try 
{
	$Command = Get-Command -Name pip -ErrorAction Stop
	$PYTHON = "python"
}
Catch {}

if ($PYTHON -eq "")
{

	DownloadFile $PythonURL "$PSScriptRoot\app\python-setup.exe"
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




Write-Host "检测Git"
Try{
	$Command = Get-Command -Name git -ErrorAction Stop
	$GIT = "git"
}Catch {}

Try{
	$Command = Get-Command -Name "$PSScriptRoot\app\git\cmd\git" -ErrorAction Stop
	$GIT = "$PSScriptRoot\app\git\cmd\git"
}
Catch {}

if ($GIT -eq "")
{
	DownloadFile $GitURL "$PSScriptRoot\app\git.zip"
	Remove-Item -LiteralPath "$PSScriptRoot\app\git\" -Recurse -ErrorAction SilentlyContinue
	Unzip "$PSScriptRoot\git.zip" "$PSScriptRoot\app\git\"
	Remove-Item -LiteralPath "$PSScriptRoot\app\git.zip" -ErrorAction SilentlyContinue
	Try {
		$Command = Get-Command -Name "$PSScriptRoot\app\git\cmd\git" -ErrorAction Stop
		$GIT = "$PSScriptRoot\app\git\cmd\git"
	}Catch {
		Write-Host "无法加载Git!" -ForegroundColor red
		Exit
	}
}


#检测Pallas-Bot
if (-Not (Test-Path -Path ".\nonebotPallas\bot.py" -PathType Leaf))
{
    Write-Host "没有找到Pallas-Bot，正在尝试从gitee仓库clong"
	& "$GIT" clone --depth=5 https://gitee.com/craun/Pallas-Bot nonebotPallas
}


Write-Host "Git: $GIT" -ForegroundColor green
cd "$PSScriptRoot\nonebotPallas"
if (($args[0] -eq "--update") -or ($args[0] -eq "-u"))
{

	& "$GIT" fetch --depth=1
	& "$GIT" reset --hard origin/master
	Write-Host "更新操作已执行完毕" -ForegroundColor green

}
elseif (($args[0] -eq "--revert") -or ($args[0] -eq "-r"))
{

	& "$GIT" reset --hard "HEAD@{1}"
	Write-Host "回滚操作已执行完毕" -ForegroundColor green

}
elseif (($args[0] -eq "--revert") -or ($args[0] -eq "-t"))
{

	Write-Host "检测ffmpeg"
	Try{
		$Command = Get-Command -Name ffmpeg -ErrorAction Stop
		$FFMPEG = "ffmpeg"
	}Catch {}

	Try{
		$Command = Get-Command -Name "$PSScriptRoot\app\ffmpeg\bin\ffmpeg" -ErrorAction Stop
		$FFMPEG = "$PSScriptRoot\app\ffmpeg\bin\ffmpeg"
	}
	Catch {}

	if ($FFMPEG -eq "")
	{
		Write-Host "Pallas-Bot将会使用ffmpeg发送语音（如果你不希望Pallas-Bot发送语音，可以不装这个）"
		$value = Read-Host -Prompt "请问是否需要Pallasbot-helper为博士安装ffmpeg？（[yes]/no）"
		if( -Not ($value -match '^n')){
			
			Try {
				$Command = Get-Command -Name ffmpeg -ErrorAction Stop
				Write-Host "已在系统环境中找到ffmpeg"
			}Catch {
				Write-Host "开始下载ffmpeg，请耐心等待"
				mkdir "$PSScriptRoot\app\"
				curl -o "$PSScriptRoot\app\ffmpeg.7z" "$FfmpegURL"
				Remove-Item -LiteralPath "$PSScriptRoot\app\ffmpeg-5.1-full_build\" -Recurse -ErrorAction SilentlyContinue
				Unzip "$PSScriptRoot\app\ffmpeg.7z" "$PSScriptRoot\app\"
				[Environment]::SetEnvironmentVariable("PATH", $Env:PATH + ";$PSScriptRoot\app\ffmpeg-5.1-full_build\bin", [EnvironmentVariableTarget]::Machine)
				Write-Host "尝试将ffmpeg写入PATH"
			}
		}else{
			Write-Host "跳过ffmpeg安装"
		}
	}

	Write-Host "即将下载Microsoft Visual C++ Build Tools 14.0"
	Write-Host "温馨提示：需要安装的是 “构建工具” 不是 “运行库” ！" -ForegroundColor red
	$value = Read-Host -Prompt "如果你已经安装过了Microsoft Visual C++ Build Tools 14.0 ，可以输入already跳过安装（输入其他内容则将开始下载）"
	if( -Not ($value -match '^already')){
		Write-Host "开始下载Microsoft Visual C++ Build Tools，请耐心等待（这个过程大约需要3-15分钟，依网络状况而定）"
		powershell curl -o "$PSScriptRoot\visual_cpp_build_tools_2015_update_3_x64_dvd.iso" "$CppURL"
		Write-Host "Microsoft Visual C++ Build Tools 14.0下载已完成,请按照目录内的“食用说明.pdf”所示，完成MongoDB的安装"
	}

	Write-Host "Pallas-Bot将会使用MongoDB存储数据（请务必安装MongoDB）"
	$value = Read-Host -Prompt "请问是否需要Pallasbot-helper为博士下载MongoDB？（yes/[no]）"
	if($value -match '^y'){
		Write-Host "开始下载MongoDB，请耐心等待（这个过程大约需要3-15分钟，依网络状况而定）"
		Write-Host "如果需要手动下载并安装MongoDB请参考以下链接"
		Write-Host "https://www.runoob.com/mongodb/mongodb-window-install.html"
		curl -o "$PSScriptRoot\Mongodb-6.0.0-windows-amd64-setup.msi" "$MongodbURL"
		Write-Host "MongoDB下载已完成,请按照目录内的“食用说明.pdf”所示，完成MongoDB的安装"
	}else{
		Write-Host "跳过MongoDB安装"
	}
	$DB = 1
	Write-Host "已完成对运行环境的检查"
}
else
{
	net start MongoDB

	# Pallas-Bot自带的requirements有问题，暂时还不清楚怎么修
	cd ..
    python -m pip install --upgrade pip -i https://mirror.baidu.com/pypi/simple
    pip install -i https://mirror.baidu.com/pypi/simple -r requirements.txt
	cd "$PSScriptRoot\nonebotPallas"

	nb plugin install nonebot_plugin_apscheduler
	nb plugin install gocqhttp
    Write-Host "正在加载$PSScriptRoot"
	nb run
}
if ($DB == 0) {
	net stop MongoDB
}
	
pause