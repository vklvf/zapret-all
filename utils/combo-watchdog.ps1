param(
    [Parameter(Mandatory = $true)]
    [int]$ParentPid
)

while (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 2
}

Stop-Process -Name winws -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Stop-Process -Name TgWsProxy_windows -Force -ErrorAction SilentlyContinue
