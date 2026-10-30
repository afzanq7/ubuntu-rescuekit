#!/usr/bin/env bash

# Ubuntu RescueKit - Server Health Checker
# Initial version: 0.1
# Purpose: Read-only Ubuntu server diagnostics

set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/reports"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
REPORT_FILE="$REPORT_DIR/health-$TIMESTAMP.txt"

# Thresholds
DISK_WARNING=80
DISK_CRITICAL=90
INODE_WARNING=80
INODE_CRITICAL=90

# Display output on screen and save it to a report.
exec > >(tee "$REPORT_FILE") 2>&1

echo "=========================================="
echo "       UBUNTU RESCUEKIT"
echo "       SERVER HEALTH REPORT"
echo "=========================================="
echo "Hostname : $(hostname)"
echo "Date     : $(date)"
echo "OS       : $(. /etc/os-release && echo "$PRETTY_NAME")"
echo "------------------------------------------"

# ========================================================
# FUNCTION DEFINITIONS
# ========================================================

# 1. CPU AND SYSTEM LOAD
check_cpu() {
    echo
    echo "[1] CPU AND SYSTEM LOAD"
    echo "------------------------------------------"

    echo "CPU cores: $(nproc)"
    echo "System uptime:"
    uptime -p

    echo "Load averages (1, 5, 15 minutes):"
    awk '{print $1, $2, $3}' /proc/loadavg

    echo "Note: Load average is not CPU utilization."
}

# 2. MEMORY
check_memory() {
    echo
    echo "[2] MEMORY USAGE"
    echo "------------------------------------------"

    free -h

    awk '
    /^Mem:/ {
        if ($2 > 0) {
            usage = (($2 - $7) / $2) * 100
            printf "Estimated memory pressure (based on MemAvailable): %.1f%%\n", usage

            if (usage >= 90)
                print "WARNING: Memory availability is low."
            else
                print "Memory availability check completed."
        }
    }' < <(free -b)
}

# 3. DISK SPACE
check_disk() {
    echo
    echo "[3] DISK SPACE"
    echo "------------------------------------------"

    df -h -x tmpfs -x devtmpfs

    echo
    echo "Disk usage assessment:"

    df -P -x tmpfs -x devtmpfs | awk -v warning="$DISK_WARNING" \
        -v critical="$DISK_CRITICAL" '
    NR > 1 {
        usage = $5
        gsub(/%/, "", usage)

        if (usage >= critical)
            printf "CRITICAL: %s is %s%% full\n", $6, usage
        else if (usage >= warning)
            printf "WARNING: %s is %s%% full\n", $6, usage
        else
            printf "OK: %s is %s%% full\n", $6, usage
    }'
}

# 4. INODE USAGE
check_inodes() {
    echo
    echo "Inode usage assessment:"

    df -Pi -x tmpfs -x devtmpfs | awk -v warning="$INODE_WARNING" \
        -v critical="$INODE_CRITICAL" '
    NR > 1 {
        usage = $5
        mount = $6

        if (usage == "-") {
            printf "SKIP: %s - Inode statistics unavailable.\n", mount
            next
        }

        gsub(/%/, "", usage)

        if (usage >= critical)
            printf "CRITICAL: %s inode usage is %s%%\n", mount, usage
        else if (usage >= warning)
            printf "WARNING: %s inode usage is %s%%\n", mount, usage
        else
            printf "OK: %s inode usage is %s%%\n", mount, usage
    }'
}

# 5. SYSTEM UPTIME
check_uptime() {
    echo
    echo "[5] SYSTEM UPTIME"
    echo "------------------------------------------"

    uptime
    echo "Last boot time:"
    who -b
}

# 6. SYSTEMD SERVICE FAILURE INVESTIGATION
check_services() {
    echo
    echo "[6] SYSTEMD SERVICE FAILURE INVESTIGATION"
    echo "------------------------------------------"

    echo "Checking for failed services..."

    # Run systemctl and check whether the command succeeded.
    if ! failed_services="$(systemctl --failed --type=service --no-legend --plain)"; then
        echo "ERROR: Unable to retrieve failed systemd services."
        echo "Check whether systemd is running and accessible."
        return 1
    fi

    # An empty result means the check succeeded but found no failures.
    if [[ -z "$failed_services" ]]; then
        echo "OK: No failed systemd services detected."
        return 0
    fi

    echo
    echo "Failed services detected:"
    echo "$failed_services"

    # Investigate each failed service.
    while read -r service _; do
        [[ -z "$service" ]] && continue

        echo
        echo "Service: $service"
        echo "------------------------------------------"

        echo "Service properties:"

        if ! systemctl show "$service" \
            -p ActiveState \
            -p SubState \
            -p Result \
            -p ExecMainCode \
            -p ExecMainStatus \
            -p MainPID; then
            echo "WARNING: Unable to retrieve properties for $service."
        fi

        echo
        echo "Recent service logs (last 50 entries):"

        if ! journalctl -u "$service" -n 50 --no-pager; then
            echo "WARNING: Unable to retrieve journal logs for $service."
        fi

    done <<< "$failed_services"
}

# ========================================================
# EXECUTE ALL DIAGNOSTIC CHECKS
# ========================================================

check_cpu
check_memory
check_disk
check_inodes
check_uptime
check_services

# 7. NETWORK DIAGNOSTICS
check_network() {
    echo
    echo "[7] NETWORK DIAGNOSTICS"
    echo "------------------------------------------"

    echo
    echo "Network interfaces and IP addresses:"
    if ! ip -br addr; then
        echo "WARNING: Unable to retrieve network interfaces."
    fi

    echo
    echo "Network interface status:"
    if ! ip -br link; then
        echo "WARNING: Unable to retrieve interface status."
    fi

    echo
    echo "Routing table:"
    if ! ip route; then
        echo "WARNING: Unable to retrieve routing table."
    fi

    echo
    echo "DNS configuration:"
    if ! resolvectl status; then
        echo "WARNING: Unable to retrieve DNS configuration."
    fi

    echo
    echo "DNS resolution test (ubuntu.com):"
    if dns_result="$(timeout 5s getent hosts ubuntu.com 2>&1)"; then
        echo "$dns_result"
        echo "OK: DNS resolution successful."
    else
        echo "WARNING: DNS resolution failed or timed out."
        echo "$dns_result"
    fi

    echo
    echo "Listening TCP and UDP ports:"
    if ! ss -tuln; then
        echo "WARNING: Unable to retrieve listening ports."
    fi

    echo
    echo "Route to external IP (8.8.8.8):"
    if ! ip route get 8.8.8.8; then
        echo "WARNING: No route found to 8.8.8.8."
    fi
        echo
    echo "Network health assessment:"
    echo "------------------------------------------"

    # Check for an active non-loopback interface.
    if ip -o link show up | awk -F': ' '$2 != "lo" {found=1} END {exit !found}'; then
        echo "OK: Active network interface detected."
    else
        echo "WARNING: No active non-loopback interface detected."
    fi

    # Check for a globally scoped IP address.
    if ip -o addr show scope global | grep -q .; then
        echo "OK: Global IP address assigned."
    else
        echo "WARNING: No global IP address detected."
    fi

    # Check for a default route.
    if ip route show default | grep -q .; then
        echo "OK: Default route configured."
    else
        echo "WARNING: No default route configured."
    fi

    # Check DNS resolution.
    if timeout 5s getent hosts ubuntu.com >/dev/null 2>&1; then
        echo "OK: DNS resolution working."
    else
        echo "WARNING: DNS resolution failed or timed out."
    fi

    # Check whether SSH is listening on TCP port 22.
    if ss -ltnH | awk '$4 ~ /:22$/ {found=1} END {exit !found}'; then
        echo "OK: SSH port 22 is listening."
    else
        echo "WARNING: No TCP listener detected on port 22."
    fi

}
# ========================================================
# EXECUTE ALL DIAGNOSTIC CHECKS
# ========================================================

check_cpu
check_memory
check_disk
check_inodes
check_uptime
check_services
check_network

# 8. SUPPORT BUNDLE GENERATION
create_support_bundle() {
    echo
    echo "[8] SUPPORT BUNDLE GENERATION"
    echo "------------------------------------------"

    BUNDLE_DIR="$SCRIPT_DIR/support-bundles"
    mkdir -p "$BUNDLE_DIR"

    BUNDLE_TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
    umask 077
    BUNDLE_FILE="$BUNDLE_DIR/rescuekit-support-$BUNDLE_TIMESTAMP.tar.gz" 


    TEMP_DIR="$(mktemp -d)"

    if [[ -z "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
        echo "ERROR: Unable to create temporary directory."
        return 1
    fi

      # Collect system information.
uname -a > "$TEMP_DIR/kernel.txt" 2>&1 || echo "WARNING: Kernel information collection failed."

hostnamectl > "$TEMP_DIR/host-info.txt" 2>&1 || echo "WARNING: Host information collection failed."

# Collect recent system errors.

journalctl -p err -n 100 --no-pager \
    > "$TEMP_DIR/system-errors.txt" 2>&1 || echo "WARNING: Journal collection failed."
 
# Collect failed systemd services.

systemctl --failed --type=service --no-pager \
    > "$TEMP_DIR/failed-services.txt" 2>&1 || echo "WARNING: Failed-service collection failed."

    # Include the report generated during this execution.
    cp "$REPORT_FILE" "$TEMP_DIR/"

    # Create compressed archive.
    if tar -czf "$BUNDLE_FILE" -C "$TEMP_DIR" .; then
        echo "OK: Support bundle created."
        echo "Location: $BUNDLE_FILE"
        du -h "$BUNDLE_FILE"
    else
        echo "ERROR: Support bundle creation failed."
        rm -f "$BUNDLE_FILE"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Remove temporary collection directory.
    rm -rf "$TEMP_DIR"
}
# EXECUTE ALL DIAGNOSTIC CHECKS
check_cpu
check_memory
check_disk
check_inodes
check_uptime
check_services
check_network
create_support_bundle
