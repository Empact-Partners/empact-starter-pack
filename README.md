# Empact Partners — Claude Code Starter Pack

Onboarding for the Empact Partners team. Everyone on the team runs Claude Code locally; this pack wires your local setup to the shared team infrastructure.

## Prerequisites

- macOS (tested on Sonoma+)
- [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) installed
- [GitHub CLI](https://cli.github.com/) installed (`brew install gh`)
- GitHub account added to the `empact-partners` org by Vlad (send your GitHub username to him on Slack first)

## Install

```bash
bash <(curl -s https://raw.githubusercontent.com/empact-partners/empact-starter-pack/main/install.sh)
```

The script:
1. Verifies Claude Code + gh CLI installed and authenticated
2. Confirms you're a member of `empact-partners` org
3. Clones `empact-partners/empact-team` to `~/Projects/empact-team/`
4. Symlinks shared skills into `~/.claude/skills/`
5. Installs shared hooks into `~/.claude/hooks/`
6. Installs the `/sync-team` slash command
7. Copies `CLAUDE.md.template` to `~/.claude/CLAUDE.md` (if you don't already have one)
8. Copies `mcp-servers.template.json` to `~/.claude/mcp-servers.json` (you fill in creds)
9. Writes `~/.claude/backup-routes.json` for repo-aware auto-backup
10. Schedules `com.empact.team-sync` launchd job (hourly pull of shared skills)

Safe to re-run — it's idempotent.

## After install

1. Edit `~/.claude/CLAUDE.md` — fill in `{YOUR_NAME}`, `{YOUR_ROLE}`, partners you lead.
2. Ask Vlad on Slack for MCP credentials. Paste them into `~/.claude/mcp-servers.json`.
3. Clone the partner repos you work on:
   ```bash
   gh repo clone empact-partners/partner-systemone ~/Projects/empact-partners-repos/partner-systemone
   ```
4. Open Claude Code in any folder. Type `/sync-team` — should show `✓ N shared skills in sync`.
5. Test: ask Claude to "list Empact active partners from Notion". The `notion-assistant` skill should fire.

## How the system works

**Three sources of truth:**
- **Notion** — partner documentation (who, what, status, history, open items). Always start a task by reading the partner's Notion page.
- **GitHub** — files only. Your drafts, research, reports auto-commit + push to `partner-{slug}` repos.
- **Monday.com** — project tracking + task management.

**Skill sync:**
- Shared skills live in `empact-partners/empact-team` on GitHub
- `~/.claude/skills/{name}` is a symlink → `~/Projects/empact-team/skills/{name}`
- `/sync-team` pulls the latest
- Hourly launchd also pulls in background

**Auto-backup:**
- Every file you edit via Claude Code auto-commits + pushes to the owning git repo
- Works across multiple repos (team, partner-*, your personal ~/.claude)
- Controlled by `~/.claude/backup-routes.json` — only paths inside allowed roots get auto-pushed

## Troubleshooting

**`install.sh` says "Not a member of empact-partners org"**
→ Send your GitHub username to Vlad on Slack to be added.

**`/sync-team` fails with "not a repo"**
→ Re-run install.sh, or manually: `gh repo clone empact-partners/empact-team ~/Projects/empact-team`

**MCP calls fail with "not authenticated"**
→ Your `~/.claude/mcp-servers.json` still has `${PLACEHOLDERS}`. Ask Vlad for creds.

**I edited a shared skill locally, my changes disappeared after `/sync-team`**
→ Shared skills are read-only for team members. To propose a skill update, open a PR on `empact-partners/empact-team`.

**My auto-backup is pushing to the wrong repo**
→ Check `~/.claude/backup-routes.json` — only listed roots are auto-backed up. Everything else is skipped.

## Questions?

- Slack DM Vlad Shvets
- Email vlad@empact.partners
