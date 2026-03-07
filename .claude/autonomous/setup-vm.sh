#!/usr/bin/env bash
# setup-vm.sh - Rocky Linux 9 VM Provisioning for Autonomous Mode
# Part of Agentic Substrate v4.2
#
# Prerequisites: Rocky Linux 9 with root access
# Usage: sudo ./setup-vm.sh [--skip-selinux] [--skip-firewall] [--npm]

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

AGENT_USER="claude-agent"
AGENT_HOME="/home/$AGENT_USER"
AGENT_WORKSPACE="$AGENT_HOME/workspace"
CONFIG_DIR="$AGENT_HOME/.config/claude-agent"
LOG_DIR="/var/log/claude-agent"
SYSTEMD_DIR="/etc/systemd/system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKIP_SELINUX=false
SKIP_FIREWALL=false
INSTALL_METHOD="binary"

log_info()  { echo "[INFO]  $1"; }
log_ok()    { echo "[OK]    $1"; }
log_warn()  { echo "[WARN]  $1"; }
log_error() { echo "[ERROR] $1" >&2; }

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-selinux)  SKIP_SELINUX=true; shift ;;
        --skip-firewall) SKIP_FIREWALL=true; shift ;;
        --npm)           INSTALL_METHOD="npm"; shift ;;
        --help)
            echo "Usage: sudo $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-selinux   Skip SELinux policy configuration"
            echo "  --skip-firewall  Skip firewalld rule configuration"
            echo "  --npm            Install Claude Code via npm instead of native binary"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# ============================================================================
# PREFLIGHT
# ============================================================================

if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

if [ -f /etc/rocky-release ]; then
    log_info "Detected: $(cat /etc/rocky-release)"
else
    log_warn "This script is designed for Rocky Linux 9. Proceeding anyway..."
fi

# ============================================================================
# STEP 1: SYSTEM PACKAGES
# ============================================================================

log_info "Step 1: Installing system packages..."

for pkg in git bubblewrap socat jq logrotate policycoreutils-python-utils python3; do
    if ! rpm -q "$pkg" &>/dev/null; then
        dnf install -y --quiet "$pkg" 2>/dev/null || log_warn "Failed to install: $pkg"
    fi
done

log_ok "System packages installed"

# ============================================================================
# STEP 2: NODE.JS (if npm install method)
# ============================================================================

if [ "$INSTALL_METHOD" = "npm" ]; then
    log_info "Step 2: Installing Node.js 20 LTS..."
    if ! command -v node &>/dev/null; then
        dnf module enable -y nodejs:20 2>/dev/null || {
            curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
        }
        dnf install -y nodejs
    fi
    log_ok "Node.js $(node --version) installed"
else
    log_info "Step 2: Skipped (using native binary installer)"
fi

# ============================================================================
# STEP 3: CLAUDE CODE CLI
# ============================================================================

log_info "Step 3: Installing Claude Code CLI..."

if ! command -v claude &>/dev/null; then
    if [ "$INSTALL_METHOD" = "binary" ]; then
        curl -fsSL https://claude.ai/install.sh | sh 2>/dev/null || {
            log_warn "Native binary install failed. Trying npm..."
            INSTALL_METHOD="npm"
        }
    fi

    if [ "$INSTALL_METHOD" = "npm" ]; then
        npm install -g @anthropic-ai/claude-code 2>/dev/null || {
            log_error "Failed to install Claude Code CLI"
            exit 1
        }
    fi
fi

if command -v claude &>/dev/null; then
    log_ok "Claude Code CLI installed: $(claude --version 2>/dev/null || echo 'version unknown')"
else
    log_error "Claude Code CLI installation failed"
    exit 1
fi

# ============================================================================
# STEP 4: CREATE AGENT USER
# ============================================================================

log_info "Step 4: Creating dedicated agent user..."

if id "$AGENT_USER" &>/dev/null; then
    log_info "User $AGENT_USER already exists"
else
    useradd \
        --system \
        --create-home \
        --home-dir "$AGENT_HOME" \
        --shell /bin/bash \
        --comment "Claude Code Autonomous Agent" \
        "$AGENT_USER"
    log_ok "User $AGENT_USER created"
fi

mkdir -p "$AGENT_WORKSPACE" "$CONFIG_DIR" "$LOG_DIR"
chown -R "$AGENT_USER:$AGENT_USER" "$AGENT_HOME" "$LOG_DIR"
chmod 750 "$AGENT_HOME"
chmod 700 "$CONFIG_DIR"

log_ok "Directories created and permissions set"

# ============================================================================
# STEP 5: AUTHENTICATION SETUP
# ============================================================================

log_info "Step 5: Setting up authentication..."

echo ""
echo "==========================================="
echo "  Authentication Options"
echo ""
echo "  1. Claude CLI login (recommended)"
echo "     Run: sudo -u $AGENT_USER claude login"
echo ""
echo "  2. API key (optional fallback)"
echo "     Store at: $CONFIG_DIR/api-key"
echo "==========================================="
echo ""

# Check if CLI auth is already configured
if sudo -u "$AGENT_USER" bash -c 'export PATH="$HOME/.local/bin:$PATH" && claude auth status' &>/dev/null 2>&1; then
    log_ok "Claude CLI authentication already configured"
else
    log_warn "Claude CLI not yet authenticated"
    log_info "Run after setup: sudo -u $AGENT_USER bash -c 'export PATH=\"\$HOME/.local/bin:\$PATH\" && claude login'"
fi

# Also support API key fallback
API_KEY_FILE="$CONFIG_DIR/api-key"
if [ -f "$API_KEY_FILE" ]; then
    log_info "API key file also present (fallback)"
    chmod 600 "$API_KEY_FILE"
fi

# ============================================================================
# STEP 6: INSTALL AUTONOMOUS MODE FILES
# ============================================================================

log_info "Step 6: Installing autonomous mode files..."

AUTONOMOUS_DIR="$AGENT_HOME/.claude/autonomous"
mkdir -p "$AUTONOMOUS_DIR"

for f in run-autonomous.sh autonomous-config.json CLAUDE-autonomous.md; do
    if [ -f "$SCRIPT_DIR/$f" ]; then
        cp "$SCRIPT_DIR/$f" "$AUTONOMOUS_DIR/"
        log_info "  Installed: $f"
    fi
done

chmod +x "$AUTONOMOUS_DIR/run-autonomous.sh" 2>/dev/null || true
chown -R "$AGENT_USER:$AGENT_USER" "$AGENT_HOME/.claude"

log_ok "Autonomous mode files installed"

# ============================================================================
# STEP 7: SYSTEMD UNITS
# ============================================================================

log_info "Step 7: Installing systemd service and timer..."

if [ -f "$SCRIPT_DIR/claude-agent.service" ]; then
    cp "$SCRIPT_DIR/claude-agent.service" "$SYSTEMD_DIR/"
fi

if [ -f "$SCRIPT_DIR/claude-agent.timer" ]; then
    cp "$SCRIPT_DIR/claude-agent.timer" "$SYSTEMD_DIR/"
fi

systemctl daemon-reload
log_ok "systemd units installed"

echo ""
echo "  To enable the timer:  systemctl enable --now claude-agent.timer"
echo "  To run once manually: systemctl start claude-agent.service"
echo "  To check status:      systemctl status claude-agent.timer"
echo ""

# ============================================================================
# STEP 8: LOG ROTATION
# ============================================================================

log_info "Step 8: Configuring log rotation..."

cat > /etc/logrotate.d/claude-agent << EOF
$LOG_DIR/*.log $LOG_DIR/*.json {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 $AGENT_USER $AGENT_USER
    maxsize 50M
}
EOF

log_ok "Log rotation configured"

# ============================================================================
# STEP 9: SELINUX (optional)
# ============================================================================

if [ "$SKIP_SELINUX" = true ]; then
    log_info "Step 9: Skipping SELinux configuration (--skip-selinux)"
else
    log_info "Step 9: Configuring SELinux policy..."

    if command -v getenforce &>/dev/null && [ "$(getenforce)" != "Disabled" ]; then
        SELINUX_DIR="$SCRIPT_DIR/selinux"
        if [ -f "$SELINUX_DIR/claude-agent.te" ]; then
            cd /tmp
            cp "$SELINUX_DIR/claude-agent.te" .
            if checkmodule -M -m -o claude-agent.mod claude-agent.te 2>/dev/null && \
               semodule_package -o claude-agent.pp -m claude-agent.mod 2>/dev/null && \
               semodule -i claude-agent.pp 2>/dev/null; then
                log_ok "SELinux policy module installed"
            else
                log_warn "SELinux policy installation failed (non-critical)"
            fi
            rm -f claude-agent.te claude-agent.mod claude-agent.pp 2>/dev/null
        else
            log_warn "SELinux policy source not found, skipping"
        fi
    else
        log_info "SELinux not enforcing, skipping policy"
    fi
fi

# ============================================================================
# STEP 10: FIREWALL (optional)
# ============================================================================

if [ "$SKIP_FIREWALL" = true ]; then
    log_info "Step 10: Skipping firewall configuration (--skip-firewall)"
else
    log_info "Step 10: Configuring firewall rules..."

    if command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 \
            -m owner --uid-owner "$AGENT_USER" -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
        firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 1 \
            -m owner --uid-owner "$AGENT_USER" -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
        firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 2 \
            -m owner --uid-owner "$AGENT_USER" -j DROP 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        log_ok "Firewall rules configured (HTTPS out only for $AGENT_USER)"
    else
        log_warn "firewalld not found, skipping firewall configuration"
    fi
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "==========================================="
echo "  Autonomous Mode Setup Complete"
echo "==========================================="
echo ""
echo "  Agent user:    $AGENT_USER"
echo "  Workspace:     $AGENT_WORKSPACE"
echo "  Config:        $AUTONOMOUS_DIR/autonomous-config.json"
echo "  Logs:          $LOG_DIR"
echo ""
echo "  Next steps:"
echo "  1. Clone your project to $AGENT_WORKSPACE"
echo "  2. Edit $AUTONOMOUS_DIR/autonomous-config.json"
echo "  3. Enable the timer: systemctl enable --now claude-agent.timer"
echo "  4. Monitor: journalctl -u claude-agent -f"
echo ""
echo "  Manual run: sudo -u $AGENT_USER $AUTONOMOUS_DIR/run-autonomous.sh"
echo ""
