#!/usr/bin/env bash
# install-rocky.sh - One-command autonomous mode installer for Rocky Linux 9
# Part of Agentic Substrate v4.2
#
# Usage (as root):
#   curl -fsSL https://raw.githubusercontent.com/VAMFI/claude-user-memory/main/.claude/autonomous/install-rocky.sh | sudo bash
#
# Or locally:
#   sudo ./install-rocky.sh
#
# What this does:
#   1. Installs the Agentic Substrate (with autonomous mode)
#   2. Runs setup-vm.sh to provision the Rocky Linux 9 VM
#   3. Guides you through API key setup
#   4. Offers to enable the systemd timer
#
# Requirements: Rocky Linux 9, root access, internet connection

set -euo pipefail

# ============================================================================
# COLORS & LOGGING
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[*]${NC} $1"; }
ok()      { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
fail()    { echo -e "${RED}[-]${NC} $1" >&2; }
header()  { echo -e "\n${BOLD}$1${NC}"; }

# ============================================================================
# BANNER
# ============================================================================

echo ""
echo -e "${BOLD}=====================================================${NC}"
echo -e "${BOLD}  Agentic Substrate - Autonomous Mode Installer${NC}"
echo -e "${BOLD}  Rocky Linux 9 | One-Command Setup${NC}"
echo -e "${BOLD}=====================================================${NC}"
echo ""

# ============================================================================
# PREFLIGHT
# ============================================================================

if [ "$(id -u)" -ne 0 ]; then
    fail "This script must be run as root (use sudo)"
    echo ""
    echo "  Usage: sudo $0"
    echo "  Or:    curl -fsSL <url> | sudo bash"
    exit 1
fi

if [ -f /etc/rocky-release ]; then
    ok "Detected: $(cat /etc/rocky-release)"
elif [ -f /etc/redhat-release ]; then
    warn "Detected: $(cat /etc/redhat-release) (not Rocky Linux, but should work)"
else
    warn "This installer is designed for Rocky Linux 9. Continuing anyway..."
fi

# Check internet connectivity
if ! curl -sf --max-time 5 https://github.com > /dev/null 2>&1; then
    fail "No internet connection detected (cannot reach github.com)"
    exit 1
fi
ok "Internet connectivity verified"

# ============================================================================
# STEP 1: INSTALL PREREQUISITES
# ============================================================================

header "Step 1/5: Installing prerequisites..."

for pkg in git python3 bubblewrap socat jq logrotate; do
    if rpm -q "$pkg" &>/dev/null; then
        ok "$pkg already installed"
    else
        info "Installing $pkg..."
        dnf install -y --quiet "$pkg" 2>/dev/null || warn "Failed to install $pkg"
    fi
done

# ============================================================================
# STEP 2: INSTALL AGENTIC SUBSTRATE
# ============================================================================

header "Step 2/5: Installing Agentic Substrate with autonomous mode..."

INSTALL_DIR="/tmp/agentic-substrate-install-$$"

if [ -f "./install.sh" ] && [ -f "./manifest-template.json" ]; then
    info "Using local repository"
    INSTALL_DIR="$(pwd)"
else
    info "Cloning repository..."
    git clone --depth 1 https://github.com/VAMFI/claude-user-memory.git "$INSTALL_DIR" 2>/dev/null || {
        fail "Failed to clone repository"
        exit 1
    }
fi

cd "$INSTALL_DIR"

# Detect target user (prefer SUDO_USER, fall back to root)
TARGET_USER="${SUDO_USER:-root}"
TARGET_HOME=$(eval echo "~$TARGET_USER")

info "Installing for user: $TARGET_USER ($TARGET_HOME)"

# Run the installer with autonomous mode
if [ "$TARGET_USER" != "root" ]; then
    su - "$TARGET_USER" -c "cd '$INSTALL_DIR' && bash install.sh --with-autonomous --force" || {
        fail "Substrate installation failed"
        exit 1
    }
else
    bash install.sh --with-autonomous --force || {
        fail "Substrate installation failed"
        exit 1
    }
fi

ok "Agentic Substrate installed with autonomous mode"

# ============================================================================
# STEP 3: RUN VM SETUP
# ============================================================================

header "Step 3/5: Provisioning VM for autonomous operation..."

AUTONOMOUS_DIR="$TARGET_HOME/.claude/autonomous"

if [ -f "$AUTONOMOUS_DIR/setup-vm.sh" ]; then
    chmod +x "$AUTONOMOUS_DIR/setup-vm.sh"

    echo ""
    echo -e "  ${YELLOW}The VM setup will:${NC}"
    echo "    - Install Claude Code CLI"
    echo "    - Create a dedicated 'claude-agent' user"
    echo "    - Install systemd service and timer"
    echo "    - Configure log rotation"
    echo "    - (Optional) Configure SELinux and firewall"
    echo ""

    read -r -p "  Configure SELinux policy? [Y/n]: " selinux_choice
    read -r -p "  Configure firewall rules? [Y/n]: " firewall_choice

    SETUP_ARGS=""
    if [[ "${selinux_choice,,}" == "n" ]]; then
        SETUP_ARGS="$SETUP_ARGS --skip-selinux"
    fi
    if [[ "${firewall_choice,,}" == "n" ]]; then
        SETUP_ARGS="$SETUP_ARGS --skip-firewall"
    fi

    # shellcheck disable=SC2086
    bash "$AUTONOMOUS_DIR/setup-vm.sh" $SETUP_ARGS
else
    warn "setup-vm.sh not found at $AUTONOMOUS_DIR, skipping VM provisioning"
fi

# ============================================================================
# STEP 4: CONFIGURE
# ============================================================================

header "Step 4/5: Configuration..."

AGENT_CONFIG="/home/claude-agent/.claude/autonomous/autonomous-config.json"

if [ -f "$AGENT_CONFIG" ]; then
    ok "Configuration file ready at: $AGENT_CONFIG"
    echo ""
    echo "  Default settings:"
    echo "    Mode:     safe (--allowedTools whitelist)"
    echo "    Model:    claude-opus-4-6 (best quality, Sonnet fallback)"
    echo "    Schedule: every 4 hours"
    echo "    Sessions: Up to 80% of session limit (50 sessions/24h default)"
    echo "    Tasks:    self-improve (enabled), run-tests (disabled), dependency-update (disabled)"
    echo ""
    echo -e "  ${YELLOW}Edit the config to customize:${NC}"
    echo "    sudo -u claude-agent nano $AGENT_CONFIG"
    echo ""
fi

# ============================================================================
# STEP 5: WORKSPACE & ACTIVATION
# ============================================================================

header "Step 5/5: Workspace setup..."

WORKSPACE="/home/claude-agent/workspace"

if [ ! -d "$WORKSPACE/.git" ]; then
    echo ""
    echo "  Clone your project to the workspace:"
    echo ""
    echo -e "    ${BOLD}sudo -u claude-agent git clone <your-repo-url> $WORKSPACE${NC}"
    echo ""
    read -r -p "  Enter git repo URL to clone now (or press Enter to skip): " repo_url

    if [ -n "$repo_url" ]; then
        info "Cloning $repo_url..."
        su - claude-agent -c "git clone '$repo_url' '$WORKSPACE'" 2>/dev/null || {
            warn "Clone failed. You can clone manually later."
        }
        ok "Project cloned to $WORKSPACE"
    fi
else
    ok "Workspace already has a project: $WORKSPACE"
fi

echo ""
echo -e "  ${YELLOW}Enable the autonomous timer?${NC}"
echo "  This will run Claude every 4 hours on your project."
echo ""
read -r -p "  Enable now? [y/N]: " enable_timer

if [[ "${enable_timer,,}" == "y" ]]; then
    systemctl enable --now claude-agent.timer 2>/dev/null || warn "Failed to enable timer"
    ok "Timer enabled! Claude will run every 4 hours."
    echo ""
    echo "  Check status: systemctl list-timers claude-agent.timer"
    echo "  View logs:    journalctl -u claude-agent -f"
else
    info "Timer not enabled. Enable later with:"
    echo "    systemctl enable --now claude-agent.timer"
fi

# ============================================================================
# CLEANUP
# ============================================================================

if [ "$INSTALL_DIR" != "$(pwd)" ] && [[ "$INSTALL_DIR" == /tmp/* ]]; then
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo -e "${BOLD}=====================================================${NC}"
echo -e "${GREEN}  Autonomous Mode Installation Complete!${NC}"
echo -e "${BOLD}=====================================================${NC}"
echo ""
echo "  Quick Reference:"
echo "  -----------------------------------------------"
echo "  Run manually:   sudo -u claude-agent ~/.claude/autonomous/run-autonomous.sh"
echo "  Dry run:        sudo -u claude-agent ~/.claude/autonomous/run-autonomous.sh --dry-run"
echo "  List tasks:     sudo -u claude-agent ~/.claude/autonomous/run-autonomous.sh --list-tasks"
echo "  Edit config:    sudo -u claude-agent nano /home/claude-agent/.claude/autonomous/autonomous-config.json"
echo "  View logs:      journalctl -u claude-agent -f"
echo "  Timer status:   systemctl list-timers claude-agent.timer"
echo "  Enable timer:   systemctl enable --now claude-agent.timer"
echo "  Disable timer:  systemctl disable --now claude-agent.timer"
echo ""
echo "  Documentation:  ~/.claude/autonomous/README.md"
echo ""
