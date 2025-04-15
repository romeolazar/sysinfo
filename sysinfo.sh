#!/bin/bash

# ────── CONFIG ──────
RAID_MOUNT="/mnt/data"        # Change this if your RAID mount is different
RAID_DEVICE="/dev/md127"        # Your mdadm RAID device

# ────── COLORS ──────
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# ────── FUNCTIONS ──────

color_for_percent() {
  local percent=$1
  if [ "$percent" -ge 80 ]; then
    echo -ne "${RED}"
  elif [ "$percent" -ge 50 ]; then
    echo -ne "${YELLOW}"
  else
    echo -ne "${GREEN}"
  fi
}

draw_bar() {
  local used=$1
  local total=$2
  local bar_length=30
  local percent=$(( 100 * used / total ))
  local filled=$(( bar_length * used / total ))
  local empty=$(( bar_length - filled ))
  local bar=$(printf "%0.s█" $(seq 1 $filled))
  local space=$(printf "%0.s░" $(seq 1 $empty))
  color_for_percent "$percent"
  echo -e " [${bar}${space}] ${used}/${total} MB (${percent}%)${RESET}"
}

format_bytes() {
  local bytes=$1
  local kib=$((bytes / 1024))
  local mib=$((kib / 1024))
  local gib=$((mib / 1024))
  local tib=$((gib / 1024))

  if [ "$tib" -ge 1 ]; then
    printf "%.1fT" "$(echo "$bytes / 1099511627776" | bc -l)"
  elif [ "$gib" -ge 1 ]; then
    printf "%.1fG" "$(echo "$bytes / 1073741824" | bc -l)"
  elif [ "$mib" -ge 1 ]; then
    printf "%.1fM" "$(echo "$bytes / 1048576" | bc -l)"
  else
    printf "%dB" "$bytes"
  fi
}

draw_disk_bar_bytes() {
  local used=$1
  local total=$2
  local bar_length=30
  local percent=$(awk "BEGIN {printf \"%.0f\", ($used / $total) * 100}")
  local filled=$(( bar_length * percent / 100 ))
  local empty=$(( bar_length - filled ))
  local bar=$(printf "%0.s█" $(seq 1 $filled))
  local space=$(printf "%0.s░" $(seq 1 $empty))
  color_for_percent "$percent"
  echo -e " [${bar}${space}] $(format_bytes $used)/$(format_bytes $total) (${percent}%)${RESET}"
}

# ────── SYSTEM INFO ──────
echo -e "\n${BOLD}${CYAN}Logged as:${RESET} $(whoami)@$(hostname)"
echo -e "${BOLD}${CYAN}OS:${RESET} $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
echo -e "${BOLD}${CYAN}IP address (local):${RESET} $(hostname -I | awk '{print $1}')"
echo -e "${BOLD}${CYAN}Public IP address:${RESET} $(curl -s ifconfig.me)"
echo -e "${BOLD}${CYAN}Uptime:${RESET} $(uptime -p)"
echo -e "${BOLD}${CYAN}Load average:${RESET} $(uptime | awk -F'load average: ' '{ print $2 }')"

# ────── MEMORY ──────
read -r _ total used _ _ <<< $(free -m | awk '/^Mem:/ {print $1, $2, $3, $6, $7}')
echo -e "\n${BOLD}${YELLOW}Memory:${RESET}"
draw_bar "$used" "$total"

# ────── RAID DISK ──────
echo -e "\n${BOLD}${YELLOW}Disk (${RAID_MOUNT}):${RESET}"
if mountpoint -q "$RAID_MOUNT"; then
  read -r size used <<< $(df -B1 "$RAID_MOUNT" | awk 'NR==2 {print $2, $3}')
  draw_disk_bar_bytes "$used" "$size"
else
  echo -e "${RED}RAID mount point not found or not mounted!${RESET}"
fi

# ────── IPMI TEMPERATURES ──────
echo -e "\n${BOLD}${YELLOW}Hardware Health (IPMI):${RESET}"
if command -v ipmitool &> /dev/null; then
  sudo ipmitool sdr | grep -E 'Temp|FAN|CPU' | grep -v 'no reading' | while read -r line; do
    name=$(echo "$line" | awk -F'|' '{print $1}' | xargs)
    value=$(echo "$line" | awk -F'|' '{print $2}' | xargs)
    status=$(echo "$line" | awk -F'|' '{print $3}' | xargs)

    if [[ $value == *degrees* ]]; then
      temp=$(echo "$value" | grep -oE '[0-9]+')
      if [ "$temp" -ge 80 ]; then
        color=$RED
      elif [ "$temp" -ge 60 ]; then
        color=$YELLOW
      else
        color=$GREEN
      fi
      echo -e "${color}${name}: ${value} (${status})${RESET}"
    elif [[ $value == *RPM* ]]; then
      echo -e "${CYAN}${name}: ${value} (${status})${RESET}"
    fi
  done
else
  echo -e "${RED}ipmitool not installed or not configured.${RESET}"
fi

# ────── RAID HEALTH ──────
echo -e "\n${BOLD}${YELLOW}RAID Health (${RAID_DEVICE}):${RESET}"
if [ -e "$RAID_DEVICE" ]; then
  mdadm --detail "$RAID_DEVICE" | grep -E 'State :|Active Devices|Working Devices|Failed Devices'
else
  echo -e "${RED}RAID device ${RAID_DEVICE} not found.${RESET}"
fi

# ────── SERVICES ──────
echo -e "\n${BOLD}${YELLOW}Services:${RESET}"
for svc in docker cockpit.service sshd mdadm firwalld; do
    systemctl is-active --quiet "$svc" && echo -e "${GREEN}▲ $svc${RESET}"
done
echo ""