# team-ops install — Windows PowerShell
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host "==> team-ops install"
Write-Host "    root: $Root"

function Require-Cmd($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "missing: $name"
  }
}

Require-Cmd node
Require-Cmd npm
Require-Cmd git

$nodeMajor = [int](node -p "process.versions.node.split('.')[0]")
if ($nodeMajor -lt 20) { throw "Node 20+ required" }

if (-not (Test-Path "$Root\.env")) {
  Copy-Item "$Root\.env.example" "$Root\.env"
  Write-Host "created .env from .env.example"
}

Write-Host "==> npm install mcp/discord"
Push-Location "$Root\mcp\discord"
npm install --no-fund --no-audit
Pop-Location

$Gen = Join-Path $Root ".generated"
New-Item -ItemType Directory -Force -Path $Gen | Out-Null

function Render($src, $dest) {
  (Get-Content $src -Raw) -replace 'TEAM_OPS_ROOT', $Root -replace '\$\{TEAM_OPS_ROOT\}', $Root |
    Set-Content -Path $dest -NoNewline
  Write-Host "    wrote $dest"
}

Render "$Root\config\mcp\claude.json" "$Gen\claude.mcp.json"
Render "$Root\config\mcp\grok.toml" "$Gen\grok.mcp.toml"
Render "$Root\config\mcp\opencode.jsonc" "$Gen\opencode.mcp.jsonc"
Render "$Root\config\mcp\codex.toml" "$Gen\codex.mcp.toml"
Render "$Root\config\mcp\cursor.json" "$Gen\cursor.mcp.json"
Copy-Item "$Gen\claude.mcp.json" "$Root\.mcp.json" -Force

if (-not (Select-String -Path "$Root\.gitignore" -Pattern '\.generated' -Quiet -ErrorAction SilentlyContinue)) {
  Add-Content "$Root\.gitignore" "`n.generated/"
}

Write-Host ""
Write-Host "Install complete."
Write-Host "  1. Edit .env"
Write-Host "  2. .\scripts\doctor.ps1"
Write-Host "  3. discord\bot-setup.md | scripts\bootstrap-linear.md"
Write-Host "  4. gh auth login; then bash scripts/bootstrap-github.sh if Git Bash available"
Write-Host "Discord invite: https://discord.gg/9FFySeV8B"
