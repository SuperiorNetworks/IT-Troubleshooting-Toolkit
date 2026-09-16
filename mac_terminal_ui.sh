#!/bin/bash
# ==============================================================================
# Name: mac_terminal_ui.sh
# Version: Master toolkit version dynamically read from launch_menu.ps1
# Purpose: Provides the accessible, branded terminal design system used by the
#          Superior Networks macOS Troubleshooter Terminal.
# Author: Dwain Henderson Jr. | Superior Networks LLC
# Contact: (937) 985-2480 | dhenderson@superiornetworks.biz
# Copyright: 2026, Superior Networks LLC
# Location: ~/ITTools/Scripts/mac_terminal_ui.sh
#
# What This Script Does:
#   - Renders the Superior Networks terminal dashboard and optional logo image
#   - Provides accessible contrast, boxed callouts, step indicators, and cards
#   - Supplies a consistent Help Guide, instruction, and version-footer layout
#   - Falls back to clean plain text when ANSI styling is not available
#
# Input:
#   - Terminal capabilities, screen dimensions, toolkit version, and UI copy
#
# Output:
#   - Styled terminal panels and instruction callouts on standard output
#
# Dependencies:
#   - macOS 12 or later, Bash 3.2+, tput (optional), and an ANSI-capable terminal
#   - assets/superior-networks-logo.png (optional iTerm2 inline-logo enhancement)
#
# Change Log:
#   2026-09-16 v3.12.0 - Initial terminal design system (Dwain Henderson Jr.)
# ==============================================================================

set -u

SN_UI_SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SN_UI_LOGO="$SN_UI_SCRIPT_DIR/assets/superior-networks-logo.png"
SN_UI_WIDTH=72
SN_UI_COLOR=0
SN_UI_BOLD=""
SN_UI_RESET=""
SN_UI_DARK=""
SN_UI_PANEL=""
SN_UI_MUTED=""
SN_UI_TEXT=""
SN_UI_ACCENT=""
SN_UI_SUCCESS=""
SN_UI_WARNING=""
SN_UI_DANGER=""

sn_ui_initialize() {
    local terminal_width=""

    if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && command -v tput >/dev/null 2>&1; then
        terminal_width="$(tput cols 2>/dev/null || true)"
        if [ -n "$terminal_width" ] && [ "$terminal_width" -ge 50 ]; then
            SN_UI_COLOR=1
            SN_UI_BOLD="$(tput bold)"
            SN_UI_RESET="$(tput sgr0)"
            SN_UI_DARK="$(tput setaf 235)"
            SN_UI_PANEL="$(tput setaf 252)"
            SN_UI_MUTED="$(tput setaf 246)"
            SN_UI_TEXT="$(tput setaf 255)"
            SN_UI_ACCENT="$(tput setaf 250)"
            SN_UI_SUCCESS="$(tput setaf 35)"
            SN_UI_WARNING="$(tput setaf 178)"
            SN_UI_DANGER="$(tput setaf 167)"
        fi
    fi

    if [ -n "$terminal_width" ] && [ "$terminal_width" -ge 54 ]; then
        SN_UI_WIDTH=$terminal_width
        [ "$SN_UI_WIDTH" -gt 86 ] && SN_UI_WIDTH=86
    fi
}

sn_ui_repeat() {
    local character="$1"
    local count="$2"
    local output=""

    while [ "$count" -gt 0 ]; do
        output="${output}${character}"
        count=$((count - 1))
    done
    printf '%s' "$output"
}

sn_ui_line() {
    local character="${1:--}"
    sn_ui_repeat "$character" "$SN_UI_WIDTH"
    printf '\n'
}

sn_ui_center() {
    local text="$1"
    local visible_length
    local padding

    visible_length=${#text}
    padding=$(((SN_UI_WIDTH - visible_length) / 2))
    [ "$padding" -lt 0 ] && padding=0
    printf '%*s%s\n' "$padding" '' "$text"
}

sn_ui_box_top() {
    printf '%s╭' "$SN_UI_ACCENT"
    sn_ui_repeat '─' $((SN_UI_WIDTH - 2))
    printf '╮%s\n' "$SN_UI_RESET"
}

sn_ui_box_bottom() {
    printf '%s╰' "$SN_UI_ACCENT"
    sn_ui_repeat '─' $((SN_UI_WIDTH - 2))
    printf '╯%s\n' "$SN_UI_RESET"
}

sn_ui_box_print_line() {
    local text="$1"
    local text_length
    local available=$((SN_UI_WIDTH - 4))

    text_length=${#text}
    printf '%s│%s  %s%*s%s%s│%s\n' \
        "$SN_UI_ACCENT" "$SN_UI_RESET" "$text" "$((available - text_length))" '' "$SN_UI_ACCENT" "$SN_UI_ACCENT" "$SN_UI_RESET"
}

sn_ui_box_line() {
    local text="$1"
    local available=$((SN_UI_WIDTH - 4))
    local word=""
    local line=""
    local candidate=""

    if [ -z "$text" ]; then
        sn_ui_box_print_line ""
        return
    fi

    for word in $text; do
        if [ -z "$line" ]; then
            candidate="$word"
        else
            candidate="$line $word"
        fi

        if [ "${#candidate}" -gt "$available" ] && [ -n "$line" ]; then
            sn_ui_box_print_line "$line"
            line="$word"
        else
            line="$candidate"
        fi
    done

    [ -n "$line" ] && sn_ui_box_print_line "$line"
}

sn_ui_section_label() {
    local label="$1"
    printf '\n%s%s%s\n' "$SN_UI_BOLD" "$label" "$SN_UI_RESET"
    printf '%s' "$SN_UI_MUTED"
    sn_ui_line '─'
    printf '%s' "$SN_UI_RESET"
}

sn_ui_show_brand() {
    local title="$1"
    local subtitle="$2"

    clear
    printf '\n'
    sn_ui_box_top
    sn_ui_box_line "SUPERIOR NETWORKS LLC"
    sn_ui_box_line "${title}"
    sn_ui_box_line "$subtitle"
    sn_ui_box_bottom
}

sn_ui_show_optional_logo() {
    if command -v imgcat >/dev/null 2>&1 && [ -f "$SN_UI_LOGO" ] && [ -t 1 ]; then
        imgcat -W 121 -H 64 "$SN_UI_LOGO" 2>/dev/null || true
    fi
}

sn_ui_status() {
    local type="$1"
    local text="$2"
    local color="$SN_UI_TEXT"
    local label="INFO"

    case "$type" in
        success) color="$SN_UI_SUCCESS"; label="DONE" ;;
        warning) color="$SN_UI_WARNING"; label="READ" ;;
        danger)  color="$SN_UI_DANGER"; label="STOP" ;;
        action)  color="$SN_UI_ACCENT"; label="NEXT" ;;
    esac

    printf '%s[%s] %s%s\n' "$color" "$label" "$text" "$SN_UI_RESET"
}

sn_ui_instruction_card() {
    local title="$1"
    local line_one="$2"
    local line_two="${3:-}"
    local line_three="${4:-}"

    printf '\n'
    sn_ui_box_top
    sn_ui_box_line "$title"
    sn_ui_box_line ""
    sn_ui_box_line "$line_one"
    [ -n "$line_two" ] && sn_ui_box_line "$line_two"
    [ -n "$line_three" ] && sn_ui_box_line "$line_three"
    sn_ui_box_bottom
}

sn_ui_menu_card() {
    local key="$1"
    local title="$2"
    local description="$3"
    local badge="[ ${key} ]"

    printf '\n%s%s  %s%s\n' "$SN_UI_BOLD" "$badge" "$title" "$SN_UI_RESET"
    printf '      %s%s%s\n' "$SN_UI_MUTED" "$description" "$SN_UI_RESET"
}

sn_ui_step() {
    local current="$1"
    local total="$2"
    local title="$3"

    printf '\n%s%sSTEP %s OF %s%s  %s%s%s\n' \
        "$SN_UI_ACCENT" "$SN_UI_BOLD" "$current" "$total" "$SN_UI_RESET" "$SN_UI_TEXT" "$title" "$SN_UI_RESET"
    printf '%s' "$SN_UI_MUTED"
    sn_ui_line '─'
    printf '%s' "$SN_UI_RESET"
}

sn_ui_footer() {
    local version="$1"
    local help_location="$2"

    printf '\n%s' "$SN_UI_MUTED"
    sn_ui_line '─'
    printf '  Help Guide: %s  |  Superior Networks macOS Toolkit v%s\n' "$help_location" "$version"
    printf '%s\n' "$SN_UI_RESET"
}

sn_ui_wait() {
    printf '\n%sPress Return to continue...%s' "$SN_UI_BOLD" "$SN_UI_RESET"
    read -r _sn_ui_unused
}
