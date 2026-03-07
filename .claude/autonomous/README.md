# Autonomous Mode

Run Claude Code unattended on a headless VM with configurable scheduling, safety controls, and budget limits.

## Architecture

```
systemd timer
    -> claude-agent.service
        -> run-autonomous.sh
            -> reads autonomous-config.json
            -> checks circuit breaker
            -> runs: claude -p --allowedTools ... --max-turns N --max-budget-usd N
            -> parses JSON output
            -> commits results (optional)
            -> logs everything
```

## One-Command Install (Rocky Linux 9)

The easiest way to get started:

```bash
# From a fresh Rocky Linux 9 VM (as root):
sudo bash .claude/autonomous/install-rocky.sh
```

This interactive installer handles everything:
- Installs all prerequisites (git, python3, bubblewrap, etc.)
- Installs the Agentic Substrate with autonomous mode
- Provisions the VM (user, systemd, SELinux, firewall)
- Prompts for API key
- Offers to clone your project
- Optionally enables the timer

## Manual Setup (Step by Step)

### 1. Provision the VM

```bash
# On Rocky Linux 9 with root access:
sudo ./setup-vm.sh
```

This installs Claude Code, creates a `claude-agent` user, configures systemd, SELinux, and firewalld.

### 2. Configure

Edit `/home/claude-agent/.claude/autonomous/autonomous-config.json`:

- Define tasks (what to run)
- Set budget limits (max turns, max USD per run)
- Configure tool permissions (allowedTools / disallowedTools)
- Set schedule (timer interval)
- Choose model (Sonnet for cost efficiency, Opus for complex tasks)

### 3. Clone your project

```bash
sudo -u claude-agent git clone <your-repo> /home/claude-agent/workspace
```

### 4. Enable scheduling

```bash
systemctl enable --now claude-agent.timer
```

### 5. Monitor

```bash
# Follow logs
journalctl -u claude-agent -f

# Check timer status
systemctl list-timers claude-agent.timer

# Check run results
ls /var/log/claude-agent/
```

## Safety Model

### Safe Mode (default)

Uses `--allowedTools` to restrict Claude to a whitelist of safe operations:
- File read/write/edit
- Git operations
- Test runners (npm test, pytest, cargo test, etc.)
- Glob/Grep for search

Dangerous operations are explicitly blocked via `--disallowedTools`:
- `rm -rf`, `sudo`, pipe-to-bash, `chmod 777`, system commands

### Unsafe Mode (opt-in)

Set `"mode": "unsafe"` in config to use `--dangerously-skip-permissions`.

**Warning**: This gives Claude full system access. Only use on isolated VMs with no sensitive data.

### Safety Layers

1. **Budget limits**: `--max-turns` and `--max-budget-usd` cap API usage
2. **Circuit breaker**: 3 consecutive failures stops all runs until manual reset
3. **Git clean check**: Refuses to run if workspace has uncommitted changes
4. **Branch strategy**: Creates isolated branches for autonomous changes
5. **Auto-push disabled**: Changes stay local until human reviews
6. **Dedicated user**: `claude-agent` has minimal OS permissions
7. **SELinux**: Type enforcement restricts process capabilities
8. **Firewall**: Only HTTPS outbound allowed for agent user
9. **Resource limits**: systemd caps CPU (80%) and memory (2GB)
10. **Log rotation**: Prevents disk exhaustion

## Configuration Reference

See `autonomous-config.json` for all options with inline documentation (`_description` and `_*_options` fields).

### Key Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `mode` | `safe` | `safe` (allowedTools) or `unsafe` (skip permissions) |
| `safety.max_turns_global` | `30` | Maximum turns per task |
| `safety.max_budget_usd_global` | `$10.00` | Maximum spend per task |
| `safety.auto_commit` | `true` | Auto-commit changes after each task |
| `safety.auto_push` | `false` | Auto-push commits (disabled by default) |
| `safety.branch_strategy` | `autonomous/run-{timestamp}` | Git branch for changes |
| `model.primary` | `claude-sonnet-4-6` | Model for autonomous runs |
| `schedule.default_interval` | `4h` | Run frequency |

## Manual Operation

```bash
# Run all enabled tasks
sudo -u claude-agent /home/claude-agent/.claude/autonomous/run-autonomous.sh

# Run specific task
sudo -u claude-agent /home/claude-agent/.claude/autonomous/run-autonomous.sh self-improve

# Dry run (preview only)
sudo -u claude-agent /home/claude-agent/.claude/autonomous/run-autonomous.sh --dry-run

# List configured tasks
sudo -u claude-agent /home/claude-agent/.claude/autonomous/run-autonomous.sh --list-tasks
```

## Troubleshooting

### Circuit breaker open
```bash
# Check status
bash ~/.claude/validators/circuit-breaker.sh autonomous status

# Reset after investigating
bash ~/.claude/validators/circuit-breaker.sh autonomous reset
```

### Service not starting
```bash
systemctl status claude-agent.service
journalctl -u claude-agent --no-pager -n 50
```

### API key issues
```bash
# Verify key file exists and has correct permissions
ls -la /home/claude-agent/.config/claude-agent/api-key
# Should be: -rw------- claude-agent claude-agent

# Test manually
sudo -u claude-agent claude --version
```

### SELinux denials
```bash
# Check for denials
ausearch -m AVC -ts recent
# Generate allow rules
audit2allow -a -M claude-agent-fix
```

## Rollback

### Disable autonomous mode
```bash
sudo systemctl disable --now claude-agent.timer
```

### Remove completely
```bash
sudo systemctl disable --now claude-agent.timer
sudo rm -f /etc/systemd/system/claude-agent.{service,timer}
sudo systemctl daemon-reload
sudo userdel -r claude-agent
sudo rm -f /etc/logrotate.d/claude-agent
sudo semodule -r claude-agent 2>/dev/null || true
sudo firewall-cmd --permanent --direct --remove-rules-v4 filter OUTPUT 2>/dev/null || true
sudo firewall-cmd --reload 2>/dev/null || true
```
