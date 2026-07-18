# team-ops doctor — Windows
$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$envFile = Join-Path $Root ".env"
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    $p = $_.Split('=', 2)
    if ($p.Length -eq 2) { Set-Item -Path "Env:$($p[0].Trim())" -Value $p[1].Trim() }
  }
}

$ok = 0; $warn = 0; $fail = 0
function Pass($m) { Write-Host "  PASS  $m"; $script:ok++ }
function Wary($m) { Write-Host "  WARN  $m"; $script:warn++ }
function Bad($m)  { Write-Host "  FAIL  $m"; $script:fail++ }

Write-Host "==> team-ops doctor"
Write-Host "    root: $Root"

if (Get-Command node -ErrorAction SilentlyContinue) { Pass "node $(node -v)" } else { Bad "node missing" }
if (Get-Command git -ErrorAction SilentlyContinue) { Pass "git" } else { Bad "git missing" }
if (Get-Command gh -ErrorAction SilentlyContinue) {
  gh auth status 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { Pass "gh authenticated" } else { Wary "gh not logged in" }
} else { Wary "gh missing" }

if ($env:GITHUB_OWNER) { Pass "GITHUB_OWNER=$($env:GITHUB_OWNER)" } else { Wary "GITHUB_OWNER unset" }
if ($env:LINEAR_API_KEY) { Pass "LINEAR_API_KEY set" } else { Wary "LINEAR_API_KEY unset (MCP OAuth ok)" }
if ($env:DISCORD_BOT_TOKEN) { Pass "DISCORD_BOT_TOKEN set (not validated in PS doctor)" } else { Wary "DISCORD_BOT_TOKEN unset" }

if (Test-Path "$Root\mcp\discord\node_modules") { Pass "discord MCP deps" } else { Wary "run install.ps1" }
if (Test-Path "$Root\.mcp.json") { Pass "MCP snippets present" } else { Wary "run install.ps1" }

Write-Host ""
Write-Host "summary: pass=$ok warn=$warn fail=$fail"
if ($fail -gt 0) { exit 1 }
