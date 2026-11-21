## sysinfo

A system overview for Linux, drawn as a table. Meant to run at login, but works from any shell.

Sections: Identity (host, OS, CPU, RAM, uptime, last updates, last login), Network (public IP,
local IPs with link speed, bond status), System Resources, Top 5 CPU Processes, Storage,
Drives (SMART), RAID Health and Hardware Health (temperatures, fans).

Sections and rows only appear when the system has the data: no bond, no RAID or no sensors
means no section for it. Missing tools are reported, never installed.

### Install

For one user:

```
sudo install -m 755 sysinfo /usr/local/bin/sysinfo
```

To show it at login for all users, call it from a profile script:

```
echo '/usr/local/bin/sysinfo' | sudo tee /etc/profile.d/sysinfo.sh
```

### Dependencies

Required: `bash`, `awk`, `free`, `ip`, `df`, `uptime`, `last` (standard on most distributions).

Optional, used when present:

| Tool | Used for |
|------|----------|
| `smartctl` (smartmontools) | Drives: model, temperature, health |
| `mdadm` | RAID Health |
| `dmidecode` | RAM model, size and speed |
| `sensors` (lm_sensors) or `ipmitool` | Hardware Health; without them the kernel thermal zones in `/sys` are used |
| `mpstat` (sysstat) | More accurate CPU usage |
| `dnf` or `apt` | Last Updates (from the dnf history or `/var/log/apt/history.log*`) |

`smartctl`, `mdadm` and `dmidecode` need root. The script calls them through `sudo`
(`sudo -n` for `dmidecode`, which never prompts). Without sudo rights, drive temperatures, RAID
state and the RAM model show as `n/a`. For passwordless use, allow those commands in sudoers.

### Notes

* Run it in a UTF-8 locale. Over `ssh host command` there is no terminal locale and `sensors`
  prints `C` instead of `°C`: use `LC_ALL=C.UTF-8 sysinfo`.
* Bonding: the active member is listed first with its link speed. Members without link are red.
* To hide mounts or block devices, edit `STORAGE_SKIP_MOUNTS` and `DRIVES_SKIP` at the top of the
  script (shell glob patterns).
* Interfaces that are virtual (docker, bridges, veth, tunnels) are not listed.
