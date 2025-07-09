#!/bin/bash

# ────── CONFIG ──────
DATA_MOUNT="/home"      # Mount point for /home data (formerly /home/cloud/data in example output)
STORAGE_MOUNT="/mnt/storage" # Mount point for /mnt/storage

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
  local label=$1 # New: label parameter for "data:", "storage:", etc.
  local used=$2
  local total=$3
  local bar_length=30
  local percent=$(awk "BEGIN {printf \"%.0f\", ($used / $total) * 100}")
  local filled=$(( bar_length * percent / 100 ))
  local empty=$(( bar_length - filled ))
  local bar=$(printf "%0.s█" $(seq 1 $filled))
  local space=$(printf "%0.s░" $(seq 1 $empty))
  color_for_percent "$percent"
  echo -e "${label} [${bar}${space}] $(format_bytes $used)/$(format_bytes $total) (${percent}%)${RESET}"
}

# ────── SYSTEM INFO ──────
echo -e "\n${BOLD}${CYAN}Logged as:${RESET} $(whoami)@$(hostname)"
echo -e "${BOLD}${CYAN}OS:${RESET} $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
echo -e "${BOLD}${CYAN}IP address (local):${RESET} $(hostname -I | awk '{print $1}')"
echo -e "${BOLD}${CYAN}Public IP address:${RESET} $(curl -s ifconfig.me)"
echo -e "${BOLD}${CYAN}Uptime:${RESET} $(uptime -p)"

# ────── MEMORY ──────
read -r _ total used _ _ <<< $(free -m | awk '/^Mem:/ {print $1, $2, $3, $6, $7}')
echo -e "\n${BOLD}${CYAN}Memory:${RESET}"
draw_bar "$used" "$total"

# ────── STORAGE USAGE ──────
echo -e "\n${BOLD}${CYAN}Storage:${RESET}" # Single "Storage" title

# /home disk usage (labeled "data:")
if mountpoint -q "$DATA_MOUNT"; then
  read -r size used <<< $(df -B1 "$DATA_MOUNT" | awk 'NR==2 {print $2, $3}')
  draw_disk_bar_bytes "data:" "$used" "$size" # Label "data:"
else
  echo -e "${RED}data (${DATA_MOUNT}) not found or not mounted!${RESET}"
fi

# /mnt/storage disk usage (labeled "storage:")
if mountpoint -q "$STORAGE_MOUNT"; then
  read -r size used <<< $(df -B1 "$STORAGE_MOUNT" | awk 'NR==2 {print $2, $3}')
  draw_disk_bar_bytes "storage:" "$used" "$size" # Label "storage:"
else
  echo -e "${RED}storage (${STORAGE_MOUNT}) not found or not mounted!${RESET}"
fi


# ────── TEMPERATURES ──────
echo -e "\n${BOLD}${CYAN}Temperatures:${RESET}"
if command -v sensors &> /dev/null; then
  sensors | grep -E 'Core|Package|temp[0-9]:' | while read -r line; do
    label=$(echo "$line" | cut -d':' -f1 | xargs)

    # Rename temp labels
    case "$label" in
      temp1) label="SYSTEM" ;;
      temp2) label="CPU" ;;
    esac

    temp=$(echo "$line" | grep -oE '[+-]?[0-9]+(\.[0-9]+)?°C' | tr -d '+°C')

    # Validate temperature value
    if [[ -z "$temp" ]] || ! [[ "$temp" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
      continue # Skip if temp is empty or not a valid number
    fi
    if echo "$temp < -50" | bc -l | grep -q 1; then
      continue # Skip unrealistically low temperatures
    fi

    # Color logic for temperatures
    color=$GREEN
    if echo "$temp >= 80" | bc -l | grep -q 1; then
      color=$RED
    elif echo "$temp >= 60" | bc -l | grep -q 1; then
      color=$YELLOW
    fi

    echo -e "${color}${label}: ${temp}°C${RESET}"
  done
else
  echo -e "${RED}lm_sensors not installed or not configured.${RESET}"
fi