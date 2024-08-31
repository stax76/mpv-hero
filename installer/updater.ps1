$fallback7z = Join-Path (Get-Location) "\7z\7zr.exe";
$useragent = "mpv-win-updater"

function Get-7z {
    $7z_command = Get-Command -CommandType Application -ErrorAction Ignore 7z.exe | Select-Object -Last 1
    if ($7z_command) {
        return $7z_command.Source
    }
    $7zdir = Get-ItemPropertyValue -ErrorAction Ignore "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\7-Zip" "InstallLocation"
    if ($7zdir -and (Test-Path (Join-Path $7zdir "7z.exe"))) {
        return Join-Path $7zdir "7z.exe"
    }
    if (Test-Path $fallback7z) {
        return $fallback7z
    }
    return $null
}

function Check-7z {
    if (-not (Get-7z))
    {
        $null = New-Item -ItemType Directory -Force (Split-Path $fallback7z)
        $download_file = $fallback7z
        Write-Host "Downloading 7zr.exe" -ForegroundColor Green
        Invoke-WebRequest -Uri "https://www.7-zip.org/a/7zr.exe" -UserAgent $useragent -OutFile $download_file
    }
    else
    {
        Write-Host "7z already exist. Skipped download" -ForegroundColor Green
    }
}

function Check-PowershellVersion {
    $version = $PSVersionTable.PSVersion.Major
    Write-Host "Checking Windows PowerShell version -- $version" -ForegroundColor Green
    if ($version -le 2)
    {
        Write-Host "Using Windows PowerShell $version is unsupported. Upgrade your Windows PowerShell." -ForegroundColor Red
        throw
    }
}

function Check-Ytplugin {
    $ytdlp = Get-ChildItem "yt-dlp*.exe" -ErrorAction Ignore
    $youtubedl = Get-ChildItem "youtube-dl.exe" -ErrorAction Ignore
    if ($ytdlp) {
        return $ytdlp.ToString()
    }
    elseif ($youtubedl) {
        return $youtubedl.ToString()
    }
    else {
        return $null
    }
}

function Check-Ytplugin-In-System {
    $ytp = Get-Command -CommandType Application -ErrorAction Ignore yt-dlp.exe | Select-Object -Last 1
    if (-not $ytp) {
        $ytp = Get-Command -CommandType Application -ErrorAction Ignore youtube-dl.exe | Select-Object -Last 1
    }
    return [bool]($ytp -and ((Split-Path $ytp.Source) -ne (Get-Location)))
}

function Check-Mpv {
    $mpv = (Get-Location).Path + "\mpv.exe"
    $is_exist = Test-Path $mpv
    return $is_exist
}

function Download-Archive ($filename, $link) {
    Write-Host "Downloading" $filename -ForegroundColor Green
    Invoke-WebRequest -Uri $link -UserAgent $useragent -OutFile $filename
}

function Download-Ytplugin ($plugin, $version) {
    $link = ""
    $plugin_exe = ""
    switch -wildcard ($plugin) {
        "yt-dlp*" {
            Write-Host "Downloading $plugin ($version)" -ForegroundColor Green
            $32bit = ""
            if (-Not (Test-Path (Join-Path $env:windir "SysWow64"))) {
                $32bit = "_x86"
            }
            $ytdlp_channel = Check-Ytdlp-Channel
            if ($ytdlp_channel -eq 'stable') {
                $repo = "https://github.com/yt-dlp/yt-dlp"
            }
            elseif ($ytdlp_channel -eq 'nightly') {
                $repo = "https://github.com/yt-dlp/yt-dlp-nightly-builds"
            }
            elseif ($ytdlp_channel -eq 'master') {
                $repo = "https://github.com/yt-dlp/yt-dlp-master-builds"
            }
            $link = -join($repo, "/releases/download/", $version, "/", $plugin, $32bit, ".exe")
            $plugin_exe = -join($plugin, $32bit, ".exe")
        }
        "youtube-dl" {
            Write-Host "Downloading $plugin ($version)" -ForegroundColor Green
            $link = -join("https://yt-dl.org/downloads/", $version, "/youtube-dl.exe")
            $plugin_exe = "youtube-dl.exe"
        }
    }
    Invoke-WebRequest -Uri $link -UserAgent $useragent -OutFile $plugin_exe
}

function Extract-Archive ($file) {
    $7z = Get-7z
    Write-Host "Extracting" $file -ForegroundColor Green
    & $7z x -y $file
}

function Get-Latest-Mpv($Arch) {
    $filename = ""
    $download_link = ""
    $api_gh = "https://api.github.com/repos/zhongfly/mpv-winbuild/releases/latest"
    $json = Invoke-WebRequest $api_gh -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing | ConvertFrom-Json
    $filename = $json.assets | where { $_.name -Match "mpv-$Arch-[0-9]{8}" } | Select-Object -ExpandProperty name
    $download_link = $json.assets | where { $_.name -Match "mpv-$Arch-[0-9]{8}" } | Select-Object -ExpandProperty browser_download_url
    if ($filename -is [array]) {
        return $filename[0], $download_link[0]
    }
    else {
        return $filename, $download_link
    }
}

function Get-Latest-Ytplugin ($plugin) {
    switch -wildcard ($plugin) {
        "yt-dlp*" {
            $ytdlp_channel = Check-Ytdlp-Channel
            if ($ytdlp_channel -eq 'stable') {
                $repo = "https://github.com/yt-dlp/yt-dlp"
            }
            elseif ($ytdlp_channel -eq 'nightly') {
                $repo = "https://github.com/yt-dlp/yt-dlp-nightly-builds"
            }
            elseif ($ytdlp_channel -eq 'master') {
                $repo = "https://github.com/yt-dlp/yt-dlp-master-builds"
            }
            $link = -join($repo, "/releases.atom")
            Write-Host "Fetching RSS feed for yt-dlp $ytdlp_channel" -ForegroundColor Green
            $resp = [xml](Invoke-WebRequest $link -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing).Content
            $link = $resp.feed.entry[0].link.href
            $version = $link.split("/")[-1]
            return $version
        }
        "youtube-dl" {
            $link = "https://yt-dl.org/downloads/latest/youtube-dl.exe"
            Write-Host "Fetching RSS feed for youtube-dl" -ForegroundColor Green
            $resp = Invoke-WebRequest $link -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing
            $redirect_link = $resp.Headers.Location
            $version = $redirect_link.split("/")[4]
            return $version
        }
    }
}

function Get-Latest-FFmpeg ($Arch) {
    $api_gh = "https://api.github.com/repos/zhongfly/mpv-winbuild/releases/latest"
    $json = Invoke-WebRequest $api_gh -MaximumRedirection 0 -ErrorAction Ignore -UseBasicParsing | ConvertFrom-Json
    $filename = $json.assets | where { $_.name -Match "ffmpeg-$Arch-git-" } | Select-Object -ExpandProperty name
    $download_link = $json.assets | where { $_.name -Match "ffmpeg-$Arch-git-" } | Select-Object -ExpandProperty browser_download_url
    if ($filename -is [array]) {
        return $filename[0], $download_link[0]
    }
    else {
        return $filename, $download_link
    }
}

function Get-Arch {
    # Reference: http://superuser.com/a/891443
    $FilePath = [System.IO.Path]::Combine((Get-Location).Path, 'mpv.exe')
    [int32]$MACHINE_OFFSET = 4
    [int32]$PE_POINTER_OFFSET = 60

    [byte[]]$data = New-Object -TypeName System.Byte[] -ArgumentList 4096
    $stream = New-Object -TypeName System.IO.FileStream -ArgumentList ($FilePath, 'Open', 'Read')
    $stream.Read($data, 0, 4096) | Out-Null

    # DOS header is 64 bytes, last element, long (4 bytes) is the address of the PE header
    [int32]$PE_HEADER_ADDR = [System.BitConverter]::ToInt32($data, $PE_POINTER_OFFSET)
    [int32]$machineUint = [System.BitConverter]::ToUInt16($data, $PE_HEADER_ADDR + $MACHINE_OFFSET)

    $result = "" | select FilePath, FileType
    $result.FilePath = $FilePath

    switch ($machineUint)
    {
        0      { $result.FileType = 'Native' }
        0x014c { $result.FileType = 'i686' } # 32bit
        0x0200 { $result.FileType = 'Itanium' }
        0x8664 { $result.FileType = 'x86_64' } # 64bit
    }

    $stream.Close()
    $result
}

function ExtractGitFromFile {
    $stripped = .\mpv --no-config | select-string "mpv" | select-object -First 1
    $pattern = "-g([a-z0-9-]{7})"
    $bool = $stripped -match $pattern
    return $matches[1]
}

function ExtractGitFromURL($filename) {
    $pattern = "-git-([a-z0-9-]{7})"
    $bool = $filename -match $pattern
    return $matches[1]
}

function ExtractDateFromFile {
    $date = (Get-Item ./mpv.exe).LastWriteTimeUtc
    $day = $date.Day.ToString("00")
    $month = $date.Month.ToString("00")
    $year = $date.Year.ToString("0000")
    return "$year$month$day"
}

function ExtractDateFromURL($filename) {
    $pattern = "mpv-[xi864_].*-([0-9]{8})-git-([a-z0-9-]{7})"
    $bool = $filename -match $pattern
    return $matches[1]
}

function Test-Admin
{
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function  Create-XML{
@"
<settings>
  <arch>unset</arch>
  <autodelete>unset</autodelete>
  <getffmpeg>unset</getffmpeg>
  <getytdl>unset</getytdl>
  <ytdlpchannel>unset</ytdlpchannel>
</settings>
"@ | Set-Content "settings.xml" -Encoding UTF8
}

function Check-Arch($arch) {
    $get_arch = ""
    $file = "settings.xml"

    if (-not (Test-Path $file)) { Create-XML }
    [xml]$doc = Get-Content $file
    if ($doc.settings.arch -eq "unset") {
        if ($arch -eq "i686") {
            $get_arch = "i686"
        }
        else {
            $result = Read-KeyOrTimeout "Choose variant for 64bit builds: x86_64 or x86_64-v3 (for cpu with AVX2 support) [1=x86_64 / 2=x86_64-v3 (default=1)" "D1"
            Write-Host ""
            if ($result -eq 'D1') {
                $get_arch = "x86_64"
            }
            elseif ($result -eq 'D2') {
                $get_arch = "x86_64-v3"
            }
            else {
                throw "Please enter valid input key."
            }
        }
        $doc.settings.arch = $get_arch
        $doc.Save($file)
    }
    else {
        $get_arch = $doc.settings.arch
    }
    return $get_arch
}

function Check-Autodelete($archive) {
    $autodelete = ""
    $file = "settings.xml"

    if (-not (Test-Path $file)) { exit }
    [xml]$doc = Get-Content $file
    if ($doc.settings.autodelete -eq "unset") {
        $result = Read-KeyOrTimeout "Delete archives after extract? [Y/n] (default=Y)" "Y"
        Write-Host ""
        if ($result -eq 'Y') {
            $autodelete = "true"
        }
        elseif ($result -eq 'N') {
            $autodelete = "false"
        }
        else {
            throw "Please enter valid input key."
        }
        $doc.settings.autodelete = $autodelete
        $doc.Save($file)
    }
    if ($doc.settings.autodelete -eq "true") {
        if (Test-Path $archive)
        {
            Remove-Item -Force $archive
        }
    }
}

function Check-GetFFmpeg() {
    $get_ffmpeg = ""
    $file = "settings.xml"

    if (-not (Test-Path $file)) { exit }
    [xml]$doc = Get-Content $file
    if ($doc.settings.getffmpeg -eq "unset") {
        Write-Host "FFmpeg doesn't exist. " -ForegroundColor Green -NoNewline
        $result = Read-KeyOrTimeout "Proceed with downloading? [Y/n] (default=n)" "N"
        Write-Host ""
        if ($result -eq 'Y') {
            $get_ffmpeg = "true"
        }
        elseif ($result -eq 'N') {
            $get_ffmpeg = "false"
        }
        else {
            throw "Please enter valid input key."
        }
        $doc.settings.getffmpeg = $get_ffmpeg
        $doc.Save($file)
    }
    else {
        $get_ffmpeg = $doc.settings.getffmpeg
    }
    return $get_ffmpeg
}

function Check-GetYTDL() {
    $get_ytdl = ""
    $file = "settings.xml"

    if (-not (Test-Path $file)) { exit }
    [xml]$doc = Get-Content $file
    if ($null -eq $doc.settings.getytdl) {
		$yt = Check-Ytplugin
		if ($yt -eq $null){
			$get_ytdl = "unset"
		}
		elseif ((Get-Item $yt).BaseName -Match "yt-dlp*") {
			$get_ytdl = "ytdlp"
		}
		else {
			$get_ytdl = "youtubedl"
		}
		$newNode = $doc.CreateElement("getytdl")
		$newNode.AppendChild($doc.CreateTextNode($get_ytdl)) | out-null
		$doc.settings.appendchild($newNode) | out-null
		$doc.Save($file)
    }
    else {
		$get_ytdl = $doc.settings.getytdl
    }
    
    if ($get_ytdl -eq "unset") {
        $result = Read-KeyOrTimeout "Download ytdlp or youtubedl? [1=ytdlp/2=youtubedl/N] (default=1)" "D1"
        Write-Host ""
        if ($result -eq 'D1') {
            $get_ytdl = "ytdlp"
        }
        elseif ($result -eq 'D2') {
            $get_ytdl = "youtubedl"
        }
        elseif ($result -eq 'N') {
            $get_ytdl = "false"
        }
        else {
            throw "Please enter valid input key."
        }
        $doc.settings.getytdl = $get_ytdl
        $doc.Save($file)
    }

    return $get_ytdl
}

function Check-Ytdlp-Channel() {
    $ytdlp_channel = ""
    $file = "settings.xml"

    if (-not (Test-Path $file)) { exit }
    [xml]$doc = Get-Content $file
    if ($null -eq $doc.settings.ytdlpchannel) {
        $newNode = $doc.CreateElement("ytdlpchannel")
        $newNode.AppendChild($doc.CreateTextNode("unset")) | out-null
        $doc.settings.appendchild($newNode) | out-null
    }
    if ($doc.settings.ytdlpchannel -eq "unset") {
        $result = Read-KeyOrTimeout "Which update channel to update yt-dlp to? [1=stable/2=nightly/3=master] (default=1)" "D1"
        Write-Host ""
        if ($result -eq 'D1') {
            $ytdlp_channel = "stable"
        }
        elseif ($result -eq 'D2') {
            $ytdlp_channel = "nightly"
        }
        elseif ($result -eq 'D3') {
            $ytdlp_channel = "master"
        }
        else {
            throw "Please enter valid input key."
        }
        $doc.settings.ytdlpchannel = $ytdlp_channel
        $doc.Save($file)
    }
    else {
        $ytdlp_channel = $doc.settings.ytdlpchannel
    }
    return $ytdlp_channel
}

function Upgrade-Mpv {
    $need_download = $false
    $remoteName = ""
    $download_link = ""
    $arch = ""

    if (Check-Mpv) {
        $file_arch = (Get-Arch).FileType
        $arch = Check-Arch $file_arch
        $remoteName, $download_link = Get-Latest-Mpv $arch
        $localgit = ExtractGitFromFile
        $localdate = ExtractDateFromFile
        $remotegit = ExtractGitFromURL $remoteName
        $remotedate = ExtractDateFromURL $remoteName
        if ($localgit -match $remotegit)
        {
            if ($localdate -match $remotedate)
            {
                Write-Host "You are already using latest mpv build -- $remoteName" -ForegroundColor Green
                $need_download = $false
            }
            else {
                Write-Host "Newer mpv build available" -ForegroundColor Green
                $need_download = $true
            }
        }
        else {
            Write-Host "Newer mpv build available" -ForegroundColor Green
            $need_download = $true
        }
    }
    else {
        Write-Host "mpv doesn't exist. " -ForegroundColor Green -NoNewline
        $result = Read-KeyOrTimeout "Proceed with downloading? [Y/n] (default=y)" "Y"
        Write-Host ""

        if ($result -eq 'Y') {
            $need_download = $true
            if (Test-Path (Join-Path $env:windir "SysWow64")) {
                Write-Host "Detecting System Type is 64-bit" -ForegroundColor Green
                $original_arch = "x86_64"
            }
            else {
                Write-Host "Detecting System Type is 32-bit" -ForegroundColor Green
                $original_arch = "i686"
            }
            $arch = Check-Arch $original_arch
            $remoteName, $download_link = Get-Latest-Mpv $arch
        }
        elseif ($result -eq 'N') {
            $need_download = $false
        }
        else {
            throw "Please enter valid input key."
        }
    }

    if ($need_download) {
        Download-Archive $remoteName $download_link
        Check-7z
        Extract-Archive $remoteName
    }
    Check-Autodelete $remoteName
}

function Upgrade-Ytplugin {
    if (Check-Ytplugin-In-System) {
        Write-Host "yt-dlp.exe or youtube-dl.exe already exists in your system, skip the update check." -ForegroundColor Green
        return
    }
    $yt = Check-Ytplugin
    if ($yt) {
        $latest_release = Get-Latest-Ytplugin((Get-Item $yt).BaseName)
        if ((& $yt --version) -match ($latest_release)) {
            Write-Host "You are already using latest" (Get-Item $yt).BaseName "-- $latest_release" -ForegroundColor Green
        }
        else {
            Write-Host "Newer" (Get-Item $yt).BaseName "build available" -ForegroundColor Green
            if ((Get-Item $yt).BaseName -Match "yt-dlp*") {
                $ytdlp_channel = Check-Ytdlp-Channel
                & $yt --update-to $ytdlp_channel
            }
            else {
                & $yt --update
            }
        }
    }
    else {
        Write-Host "ytdlp or youtube-dl doesn't exist. " -ForegroundColor Green -NoNewline
        $ytdl = Check-GetYTDL
        if ($ytdl -eq 'ytdlp') {
            $latest_release = Get-Latest-Ytplugin "yt-dlp"
            Download-Ytplugin "yt-dlp" $latest_release
        }
        elseif ($ytdl -eq 'youtubedl') {
            $latest_release = Get-Latest-Ytplugin "youtube-dl"
            Download-Ytplugin "youtube-dl" $latest_release
        }
        elseif ($ytdl -ne 'false') {
            throw "Please enter valid input key."
        }
    }
}

function Upgrade-FFmpeg {
    $get_ffmpeg = Check-GetFFmpeg
    if ($get_ffmpeg -eq "false") {
        return
    }

    if (Test-Path (Join-Path $env:windir "SysWow64")) {
        $original_arch = "x86_64"
        $arch = Check-Arch $original_arch
    }
    else {
        $arch = "i686"
    }

    $need_download = $false
    $remote_name, $download_link = Get-Latest-FFmpeg $arch
    $ffmpeg = (Get-Location).Path + "\ffmpeg.exe"
    $ffmpeg_exist = Test-Path $ffmpeg

    if ($ffmpeg_exist) {
        $ffmpeg_file = .\ffmpeg -version | select-string "ffmpeg" | select-object -First 1
        $file_pattern_1 = "git-[0-9]{4}-[0-9]{2}-[0-9]{2}-(?<commit>[a-z0-9]+)" # git-2023-01-02-cc2b1a325
        $file_pattern_2 = "N-\d+-g(?<commit>[a-z0-9]+)"                         # N-109751-g9a820ec8b
        $file_pattern = $file_pattern_1, $file_pattern_2 -join '|'
        $url_pattern = "git-([a-z0-9]+)"
        $file_match= [Regex]::Matches($ffmpeg_file, $file_pattern)
        $remote_match = [Regex]::Matches($remote_name, $url_pattern)
        $local_git = $file_match[0].groups['commit'].value
        $remote_git = $remote_match[0].groups[1].value

        if ($local_git -match $remote_git) {
            Write-Host "You are already using latest ffmpeg build -- $remote_name" -ForegroundColor Green
            $need_download = $false
        }
        else {
            Write-Host "Newer ffmpeg build available" -ForegroundColor Green
            $need_download = $true
        }
    }
    else {
        $need_download = $true
    }

    if ($need_download) {
        Download-Archive $remote_name $download_link
        Check-7z
        Extract-Archive $remote_name
    }
    Check-Autodelete $remote_name
}

function Read-KeyOrTimeout ($prompt, $key){
    $seconds = 9
    $startTime = Get-Date
    $timeOut = New-TimeSpan -Seconds $seconds

    Write-Host "$prompt " -ForegroundColor Green

    # Basic progress bar
    [Console]::CursorLeft = 0
    [Console]::Write("[")
    [Console]::CursorLeft = $seconds + 2
    [Console]::Write("]")
    [Console]::CursorLeft = 1

    while (-not [System.Console]::KeyAvailable) {
        $currentTime = Get-Date
        Start-Sleep -s 1
        Write-Host "#" -ForegroundColor Green -NoNewline
        if ($currentTime -gt $startTime + $timeOut) {
            Break
        }
    }
    if ([System.Console]::KeyAvailable) {
        $response = [System.Console]::ReadKey($true).Key
    }
    else {
        $response = $key
    }
    return $response.ToString()
}

#
# Main script entry point
#
if (Test-Admin) {
    Write-Host "Running script with administrator privileges" -ForegroundColor Yellow
}
else {
    Write-Host "Running script without administrator privileges" -ForegroundColor Red
}

try {
    Check-PowershellVersion
    # Sourceforge only support TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $global:progressPreference = 'silentlyContinue'
    Upgrade-Mpv
    Upgrade-Ytplugin
    Upgrade-FFmpeg
    Write-Host "Operation completed" -ForegroundColor Magenta
}
catch [System.Exception] {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
