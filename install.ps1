# Empact Partners — Claude Code Setup (Windows)
# One-command onboarding. Idempotent — safe to re-run.
#
# Usage:
#   irm https://raw.githubusercontent.com/Empact-Partners/empact-starter-pack/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

function Log($msg) { Write-Host "==> $msg" -ForegroundColor Blue }
function Ok($msg) { Write-Host "✓ $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Err($msg) { Write-Host "✗ $msg" -ForegroundColor Red; exit 1 }

# ─── Step 1: Preflight ────────────────────────────────────────────────
Log "Preflight checks"

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Err "Claude Code CLI not installed. Install it first: https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview"
}
Ok "Claude Code CLI found"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Err "GitHub CLI not installed. Install via: winget install GitHub.cli"
}
Ok "GitHub CLI found"

$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Warn "Not logged in to GitHub. Running: gh auth login"
    gh auth login
}
Ok "GitHub authenticated"

$ghUser = gh api user -q .login 2>$null
$memberCheck = gh api "orgs/Empact-Partners/members/$ghUser" 2>&1
if ($LASTEXITCODE -ne 0) {
    Err "You are not a member of the Empact-Partners GitHub org. Ask Vlad to add you first."
}
Ok "Member of Empact-Partners org"

# ─── Step 2: Git identity ────────────────────────────────────────────
Log "Configuring identity"

if (-not (git config --global user.name)) {
    $gitName = Read-Host "Your full name"
    git config --global user.name $gitName
}
if (-not (git config --global user.email)) {
    $gitEmail = Read-Host "Your @empact.partners email"
    git config --global user.email $gitEmail
}
Ok "Git identity: $(git config --global user.name) <$(git config --global user.email)>"

# ─── Step 3: Clone empact-team ────────────────────────────────────────
Log "Cloning empact-team repo"

$projectsDir = Join-Path $env:USERPROFILE "Projects"
$teamDir = Join-Path $projectsDir "empact-team"
New-Item -ItemType Directory -Force -Path $projectsDir | Out-Null

if (Test-Path (Join-Path $teamDir ".git")) {
    Push-Location $teamDir
    git pull --ff-only origin main
    Pop-Location
    Ok "empact-team: already cloned, pulled latest"
} else {
    gh repo clone Empact-Partners/empact-team $teamDir
    Ok "empact-team: cloned"
}

# ─── Step 4: Copy shared skills ──────────────────────────────────────
Log "Copying shared skills"

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$skillsDir = Join-Path $claudeDir "skills"
New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null

$copied = 0
Get-ChildItem (Join-Path $teamDir "skills") -Directory | ForEach-Object {
    $dst = Join-Path $skillsDir $_.Name
    Copy-Item -Recurse -Force $_.FullName $dst
    $copied++
}
Ok "$copied skills copied from empact-team"

# ─── Step 5: Install hooks ───────────────────────────────────────────
Log "Installing hooks"

$hooksDir = Join-Path $claudeDir "hooks"
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null

Get-ChildItem (Join-Path $teamDir "hooks") -Filter "*.sh" | ForEach-Object {
    Copy-Item -Force $_.FullName (Join-Path $hooksDir $_.Name)
}
Ok "Hooks installed"

# ─── Step 6: Install commands ────────────────────────────────────────
Log "Installing slash commands"

$cmdsDir = Join-Path $claudeDir "commands"
New-Item -ItemType Directory -Force -Path $cmdsDir | Out-Null

Get-ChildItem (Join-Path $teamDir "commands") -Filter "*.md" | ForEach-Object {
    Copy-Item -Force $_.FullName (Join-Path $cmdsDir $_.Name)
}
Ok "Slash commands installed (/sync-team)"

# ─── Step 7: CLAUDE.md template ──────────────────────────────────────
Log "CLAUDE.md setup"

$claudeMd = Join-Path $claudeDir "CLAUDE.md"
$starterDir = Join-Path $projectsDir "empact-starter-pack"

if (-not (Test-Path $starterDir)) {
    gh repo clone Empact-Partners/empact-starter-pack $starterDir
}

if (Test-Path $claudeMd) {
    Warn "$claudeMd already exists. Not overwriting."
    Write-Host "    To use the Empact template, back up and copy from: $starterDir\CLAUDE.md.template"
} else {
    Copy-Item (Join-Path $starterDir "CLAUDE.md.template") $claudeMd
    Ok "CLAUDE.md installed — fill in {YOUR_NAME}, {YOUR_ROLE}, etc."
}

# ─── Step 8: MCP config ──────────────────────────────────────────────
Log "MCP config"

$mcpJson = Join-Path $claudeDir "mcp-servers.json"
if (Test-Path $mcpJson) {
    Warn "$mcpJson already exists. Not overwriting."
} else {
    Copy-Item (Join-Path $starterDir "mcp-servers.template.json") $mcpJson
    Ok "mcp-servers.json template installed"
    Write-Host "    ⚠ Fill in credentials. Ask Vlad on Slack for: NOTION_EMPACT_TOKEN, FIRECRAWL_API_KEY, SLACK_EMPACT_BOT_TOKEN"
}

# ─── Step 9: Backup routes + shared-skills registry ──────────────────
Log "Configuring backup routes + skill registry"

$routesFile = Join-Path $claudeDir "backup-routes.json"
if (-not (Test-Path $routesFile)) {
    @{
        "_comment" = "Repo-aware auto-backup."
        roots = @(
            $claudeDir
            $teamDir
            (Join-Path $projectsDir "empact-partners-repos")
        )
    } | ConvertTo-Json | Set-Content $routesFile
    Ok "backup-routes.json installed"
}

# Build shared-skills.json from empact-team
$registry = @{
    "_comment" = "Registry of team-shared skills."
    team_repo_path = $teamDir
    team_repo_remote = "https://github.com/Empact-Partners/empact-team.git"
    shared = @()
}
Get-ChildItem (Join-Path $teamDir "skills") -Directory | ForEach-Object {
    $registry.shared += @{
        name = $_.Name
        registered_at = (Get-Date -Format "yyyy-MM-dd")
        team_repo_path = "skills/$($_.Name)"
    }
}
$registry | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $claudeDir "shared-skills.json")
Ok "shared-skills.json: $($registry.shared.Count) skills registered"

$partnerReposDir = Join-Path $projectsDir "empact-partners-repos"
New-Item -ItemType Directory -Force -Path $partnerReposDir | Out-Null
Ok "Partner repos directory created"

# ─── Step 10: Schedule hourly team-sync (Windows Task Scheduler) ─────
Log "Scheduling hourly team-sync"

$taskName = "EmpactTeamSync"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if (-not $taskExists) {
    $action = New-ScheduledTaskAction -Execute "git" -Argument "pull --ff-only origin main" -WorkingDirectory $teamDir
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Description "Hourly pull of Empact team skills" -RunLevel Limited | Out-Null
    Ok "Hourly team-sync scheduled (Windows Task Scheduler)"
} else {
    Ok "Team-sync task already exists"
}

# ─── Done ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✓ Empact Partners Claude Code setup complete" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Edit ~/.claude/CLAUDE.md — fill in {YOUR_NAME}, {YOUR_ROLE}, etc."
Write-Host "  2. Get MCP credentials from Vlad (Slack DM)"
Write-Host "  3. Clone the partner repos you work on:"
Write-Host "     gh repo clone Empact-Partners/partner-systemone ~/Projects/empact-partners-repos/partner-systemone"
Write-Host "  4. Open Claude Code, type '/sync-team' — should show skills in sync"
Write-Host ""
