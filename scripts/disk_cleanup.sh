#!/bin/bash

# Disk Cleanup Utility
# This script helps manage disk space by cleaning up Docker resources, system caches, and finding large files.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}      Disk Cleanup Utility           ${NC}"
echo -e "${GREEN}=====================================${NC}"

show_usage() {
    echo -e "\n${YELLOW}Current Disk Usage:${NC}"
    df -h | grep -E '^Filesystem|/$'
    echo ""
    if command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker Usage:${NC}"
        docker system df
    fi
}

cleanup_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed.${NC}"
        return
    fi

    echo -e "\n${YELLOW}Docker Cleanup Options:${NC}"
    echo "1) Standard Prune (Stopped containers, dangling images, unused networks)"
    echo "2) Deep Clean (All unused images, containers, networks, volumes)"
    echo "3) Cancel"
    read -r -p "Select an option [1-3]: " docker_choice

    case $docker_choice in
        1)
            echo -e "${GREEN}Running Docker system prune...${NC}"
            docker system prune -f
            ;;
        2)
            echo -e "${RED}Warning: This will remove ALL unused images, not just dangling ones.${NC}"
            read -r -p "Are you sure? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}Running Docker system prune --all...${NC}"
                docker system prune -a -f --volumes
            else
                echo "Operation cancelled."
            fi
            ;;
        *)
            echo "Skipping Docker cleanup."
            ;;
    esac
}


cleanup_system() {
    echo -e "\n${YELLOW}System Cleanup:${NC}"
    
    # helper to run sudo non-interactively
    run_sudo() {
        if [ "$EUID" -eq 0 ]; then
            "$@"
        elif command -v sudo &> /dev/null; then
            # Try sudo non-interactively first
            if sudo -n true 2>/dev/null; then
                sudo "$@"
            else
                echo -e "${RED}Skipping system cleanup (requires root/sudo password).${NC}"
                return 0
            fi
        else
            echo -e "${RED}Skipping system cleanup (requires root).${NC}"
            return 0
        fi
    }

    # APT Cleanup
    if command -v apt-get &> /dev/null; then
        echo "Cleaning apt cache..."
        if run_sudo apt-get clean; then
             echo "Removing unused dependencies..."
             run_sudo apt-get autoremove -y
        fi
    fi

    # Journal Cleanup
    if command -v journalctl &> /dev/null; then
        echo "Vacuuming journal logs (keeping last 2 days)..."
        run_sudo journalctl --vacuum-time=2d
    fi
    
    echo -e "${GREEN}System cleanup completed.${NC}"
}


find_large_files() {
    echo -e "\n${YELLOW}Finding files larger than 500MB:${NC}"
    echo "Searching in / (excluding /proc, /sys, /dev, /run, /mnt)..."
    # Using sudo to access all directories, errors redirected to /dev/null
    sudo find / -xdev -type f -size +500M -exec ls -lh {} \; 2>/dev/null | awk '{ print $9 ": " $5 }'
}


# Main execution logic
if [[ "$1" == "--auto" ]]; then
    echo -e "${GREEN}Running in Auto Mode (Cron Compatible)...${NC}"
    date
    
    # 1. Show usage before
    echo "--- Disk Usage Before ---"
    df -h | grep -E '^Filesystem|/$'
    
    # 2. Docker Cleanup (Standard Prune only)
    if command -v docker &> /dev/null; then
        echo "Running Docker system prune -f..."
        docker system prune -f
    fi

    # 3. System Cleanup
    cleanup_system

    # 4. Show usage after
    echo "--- Disk Usage After ---"
    df -h | grep -E '^Filesystem|/$'
    
    echo "Auto cleanup finished."
    exit 0
fi

while true; do

    echo -e "\n${GREEN}Main Menu:${NC}"
    echo "1) Show Disk Usage"
    echo "2) Clean Docker Resources"
    echo "3) Clean System Cache & Logs"
    echo "4) Find Large Files (>500MB)"
    echo "5) Exit"
    
    read -r -p "Enter your choice [1-5]: " choice

    case $choice in
        1) show_usage ;;
        2) cleanup_docker ;;
        3) cleanup_system ;;
        4) find_large_files ;;
        5) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}" ;;
    esac
    
    echo -e "\nPres Enter to continue..."
    read -r
done
