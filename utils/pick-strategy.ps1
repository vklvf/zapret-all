$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent $PSScriptRoot
$resultsDir = Join-Path $PSScriptRoot "test results"
$strategyFile = Join-Path $PSScriptRoot "combo-strategy.txt"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Run pick-strategy.cmd as Administrator." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] curl.exe not found in PATH." -ForegroundColor Red
    exit 1
}

$targets = @(
    @{ Name = "YouTube"; Url = "https://www.youtube.com"; Weight = 20; DohResolve = $true },
    @{ Name = "YouTubeImage"; Url = "https://i.ytimg.com"; Weight = 5; DohResolve = $true },
    @{ Name = "Discord"; Url = "https://discord.com/app"; Weight = 3 },
    @{ Name = "DiscordGateway"; Url = "https://gateway.discord.gg"; Weight = 2 },
    @{ Name = "DiscordCDN"; Url = "https://cdn.discordapp.com"; Weight = 2 },
    @{ Name = "SoundCloud"; Url = "https://soundcloud.com"; Weight = 2 },
    @{ Name = "SoundCloudMedia"; Url = "https://cf-media.sndcdn.com"; Weight = 1 },
    @{ Name = "ChatGPT"; Url = "https://chatgpt.com"; Weight = 2 },
    @{ Name = "OpenAIStatic"; Url = "https://cdn.oaistatic.com"; Weight = 1 },
    @{ Name = "Claude"; Url = "https://claude.ai"; Weight = 2 },
    @{ Name = "Anthropic"; Url = "https://www.anthropic.com"; Weight = 1 }
)

function Stop-Bypass {
    Stop-Process -Name winws -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

function Resolve-DohA {
    param([string]$HostName)

    try {
        $uri = "https://dns.google/resolve?name=$([uri]::EscapeDataString($HostName))&type=A"
        $response = Invoke-RestMethod -Uri $uri -TimeoutSec 8
        $answer = @($response.Answer) |
            Where-Object { $_.type -eq 1 -and $_.data -match '^\d{1,3}(\.\d{1,3}){3}$' } |
            Select-Object -First 1
        if ($answer) {
            return [string]$answer.data
        }
    } catch {
        Write-Host "  [WARN] DoH resolve failed for ${HostName}: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    return $null
}

function Test-Url {
    param(
        [string]$Url,
        [bool]$DohResolve = $false
    )

    $uri = [uri]$Url

    $args = @(
        "-L",
        "--connect-timeout", "6",
        "-m", "12",
        "-o", "NUL",
        "-s",
        "-w", "%{http_code} %{time_total}",
        $Url
    )

    $resolvedIp = $null
    if ($DohResolve -and $uri.Scheme -eq "https") {
        $resolvedIp = Resolve-DohA -HostName $uri.Host
        if ($resolvedIp) {
            $args = @("--resolve", "$($uri.Host):443:$resolvedIp") + $args
        }
    }

    $output = & curl.exe @args 2>$null
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).Trim()
    $code = "000"
    $time = "0"
    if ($text -match "^(?<code>\d{3})\s+(?<time>[\d\.]+)$") {
        $code = $matches["code"]
        $time = $matches["time"]
    }

    $ok = ($exitCode -eq 0) -and ($code -ne "000") -and ([int]$code -lt 500)
    return [PSCustomObject]@{
        Url = $Url
        Ok = $ok
        Code = $code
        Time = $time
        ExitCode = $exitCode
        ResolvedIp = $resolvedIp
    }
}

$strategies = Get-ChildItem -Path $rootDir -Filter "general*.bat" |
    Sort-Object { [Regex]::Replace($_.Name, "(\d+)", { $args[0].Value.PadLeft(8, "0") }) }

if (-not $strategies) {
    Write-Host "[ERROR] No general*.bat strategies found." -ForegroundColor Red
    exit 1
}

$logPath = Join-Path $resultsDir ("combo_strategy_{0}.txt" -f (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"))
$allResults = @()

Write-Host "Testing $($strategies.Count) strategies..." -ForegroundColor Cyan
Write-Host "This will stop and restart winws.exe several times." -ForegroundColor Yellow
Write-Host ""

foreach ($strategy in $strategies) {
    Stop-Bypass

    Write-Host "=== $($strategy.Name) ===" -ForegroundColor Cyan
    $started = $false
    try {
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "`"$($strategy.FullName)`"") -WindowStyle Minimized -PassThru
        $exited = $proc.WaitForExit(15000)
        if (-not $exited) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 3
        $started = [bool](Get-Process -Name winws -ErrorAction SilentlyContinue)
    } catch {
        Write-Host "  start failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    $score = 0
    $youtubeOk = $false
    $targetResults = @()
    foreach ($target in $targets) {
        $result = Test-Url -Url $target.Url -DohResolve ([bool]$target.DohResolve)
        $targetResults += [PSCustomObject]@{
            Name = $target.Name
            Url = $target.Url
            Ok = $result.Ok
            Code = $result.Code
            Time = $result.Time
            ExitCode = $result.ExitCode
            ResolvedIp = $result.ResolvedIp
            Weight = $target.Weight
        }
        if ($result.Ok) {
            $score += $target.Weight
            if ($target.Name -eq "YouTube") {
                $youtubeOk = $true
            }
            $resolveText = if ($result.ResolvedIp) { " via $($result.ResolvedIp)" } else { "" }
            Write-Host ("  [OK]   {0,-18} HTTP {1} {2}s{3}" -f $target.Name, $result.Code, $result.Time, $resolveText) -ForegroundColor Green
        } else {
            $resolveText = if ($result.ResolvedIp) { " via $($result.ResolvedIp)" } else { "" }
            Write-Host ("  [FAIL] {0,-18} HTTP {1} exit={2}{3}" -f $target.Name, $result.Code, $result.ExitCode, $resolveText) -ForegroundColor Red
        }
    }

    if (-not $youtubeOk) {
        $score -= 100
    }

    if (-not $started) {
        Write-Host "  winws.exe was not detected after start." -ForegroundColor Yellow
    }

    $allResults += [PSCustomObject]@{
        Strategy = $strategy.Name
        Score = $score
        Started = $started
        YouTubeOk = $youtubeOk
        Targets = $targetResults
    }

    Write-Host "  score: $score" -ForegroundColor Yellow
}

Stop-Bypass

$best = $allResults |
    Sort-Object @{ Expression = "YouTubeOk"; Descending = $true }, @{ Expression = "Score"; Descending = $true }, @{ Expression = "Started"; Descending = $true } |
    Select-Object -First 1

if ($best) {
    Set-Content -Path $strategyFile -Value $best.Strategy -Encoding ASCII
}

$lines = @()
foreach ($item in $allResults) {
    $lines += "Strategy: $($item.Strategy)"
    $lines += "Score: $($item.Score)"
    $lines += "Started: $($item.Started)"
    $lines += "YouTubeOk: $($item.YouTubeOk)"
    foreach ($target in $item.Targets) {
        $lines += "  $($target.Name): ok=$($target.Ok) code=$($target.Code) time=$($target.Time) exit=$($target.ExitCode) ip=$($target.ResolvedIp) url=$($target.Url)"
    }
    $lines += ""
}
if ($best) {
    $lines += "Best strategy: $($best.Strategy)"
    $lines += "Best score: $($best.Score)"
}
Set-Content -Path $logPath -Value $lines -Encoding UTF8

if ($best) {
    Write-Host ""
    Write-Host "Best strategy: $($best.Strategy) (score $($best.Score))" -ForegroundColor Green
    Write-Host "Saved to: $strategyFile" -ForegroundColor Green
    Write-Host "Log: $logPath" -ForegroundColor Green
} else {
    Write-Host "[ERROR] No strategy was tested." -ForegroundColor Red
    exit 1
}
