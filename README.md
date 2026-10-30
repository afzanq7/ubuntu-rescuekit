# Ubuntu RescueKit

**A lightweight Bash-based Linux diagnostics and troubleshooting toolkit for Ubuntu Server.**

Ubuntu RescueKit collects essential system information, identifies common warning signs, investigates failed systemd services, performs basic network health checks, and generates a compressed diagnostic support bundle.

The goal is to make initial Linux server troubleshooting easier by collecting useful evidence in one place.

## Features

### 1. CPU and System Load
- Displays CPU core count.
- Displays system load averages.
- Shows system uptime information.

### 2. Memory Diagnostics
- Displays total, used, free and available memory.
- Estimates memory pressure using available memory.

### 3. Disk Usage
- Displays filesystem capacity and usage.
- Identifies filesystems exceeding configured warning and critical thresholds.

### 4. Inode Monitoring
- Checks inode utilization across mounted filesystems.
- Identifies potential inode exhaustion.

### 5. Uptime Information
- Displays system uptime.
- Shows the last system boot time.

### 6. systemd Service Investigation
- Identifies failed systemd services.
- Retrieves service state and exit-status information.
- Collects recent journal logs for failed services.

### 7. Network Diagnostics
- Displays network interfaces and IP addresses.
- Checks routing information and default routes.
- Checks DNS resolution.
- Lists listening TCP and UDP ports.
- Checks whether SSH is listening on TCP port 22.

### 8. Support Bundle Generation
- Collects kernel and host information.
- Collects recent system error logs.
- Collects failed systemd service information.
- Includes the generated diagnostic report.
- Packages the collected information into a compressed `.tar.gz` archive.

## Requirements

- Ubuntu Server
- Bash
- systemd
- Standard Linux utilities: `ip`, `ss`, `df`, `free`, `journalctl`, `tar`
- Appropriate permissions to access system diagnostic information

Some diagnostic commands may require `sudo` privileges.

## Installation

Clone the repository:

```bash
git clone https://github.com/afzanq7/ubuntu-rescuekit.git
```

Navigate into the project:

```bash
cd ubuntu-rescuekit
```

Make the script executable:

```bash
chmod 750 rescuekit.sh
```

## Usage

Run the toolkit:

```bash
./rescuekit.sh
```

To inspect the generated diagnostic reports:

```bash
ls -lh reports/
```

To inspect generated support bundles:

```bash
ls -lh support-bundles/
```

To list the contents of a support bundle:

```bash
tar -tzf support-bundles/<bundle-name>.tar.gz
```

## Project Structure

```text
ubuntu-rescuekit/
├── README.md
├── .gitignore
├── rescuekit.sh
├── reports/
├── support-bundles/
└── tests/
```

- `rescuekit.sh` — Main diagnostic script.
- `reports/` — Generated system health reports.
- `support-bundles/` — Compressed diagnostic archives.
- `tests/` — Project testing resources.
- `.gitignore` — Excludes generated reports and support bundles from Git.

## Safety and Design

Ubuntu RescueKit is designed primarily for read-only diagnostics.

- It does not automatically restart or stop services.
- It does not modify firewall or network configurations.
- It does not automatically delete files or change disk partitions.
- It collects diagnostic evidence to support further investigation.

Generated reports and support bundles may contain sensitive system information. Review them before sharing and avoid publishing them publicly.

## Testing

The toolkit was tested on an Ubuntu Server EC2 instance.

Testing included:
- Bash syntax validation using `bash -n`.
- Execution of the diagnostic script.
- A controlled systemd service failure simulation.
- Verification of failed-service detection and journal collection.
- Network information and DNS resolution checks.
- Support bundle generation and archive-content verification.
- Verification of private file permissions.

## Limitations

Ubuntu RescueKit performs initial diagnostics; it does not guarantee automatic root-cause identification.

Network checks do not independently verify external firewall rules, cloud security groups, or end-to-end connectivity.

The toolkit is an evolving learning project, and additional diagnostic checks can be added over time.

## Author

**Afzan Qureshi**

GitHub: https://github.com/afzanq7
