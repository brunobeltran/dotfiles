#!/bin/bash

set -euxo pipefail
shopt -s nullglob

##
# macOS system settings.
#
# These are undocumented `defaults` keys (found by diffing `defaults read`
# before/after flipping the switch in System Settings), so they may need
# updating across macOS releases. Only write keys whose value differs, so that
# re-runs don't needlessly restart the Dock.
macos_settings_changed=
# Usage: _macos_default [-currentHost] <domain> <key> <-bool|-int|-string> <value>
_macos_default() {
    local -a host=()
    if [[ $1 == -currentHost ]]; then
        host=(-currentHost)
        shift
    fi
    local domain=$1 key=$2 type=$3 value=$4 expected=$4
    if [[ ${type} == -bool ]]; then
        [[ ${value} == true ]] && expected=1 || expected=0
    fi
    if [[ "$(defaults "${host[@]}" read "${domain}" "${key}" 2>/dev/null)" != "${expected}" ]]; then
        defaults "${host[@]}" write "${domain}" "${key}" "${type}" "${value}"
        macos_settings_changed=1
    fi
}

# Non-"natural" scrolling.
_macos_default -g com.apple.swipescrolldirection -bool false

# Two-finger double-tap for smart zoom (both built-in and Magic Trackpad).
for domain in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
    _macos_default "${domain}" TrackpadTwoFingerDoubleTapGesture -int 1
done
_macos_default -currentHost -g com.apple.trackpad.twoFingerDoubleTapGesture -int 1

# Dock: tiny, on the left, magnify on hover.
_macos_default com.apple.dock orientation -string left
_macos_default com.apple.dock tilesize -int 16
_macos_default com.apple.dock magnification -bool true
_macos_default com.apple.dock largesize -int 32

# Dock apps: whichever of these are installed, then System Settings (Finder
# is always pinned and isn't stored here). Missing apps are skipped rather
# than leaving dead "?" tiles. The Dock fills in the rest of each tile's
# metadata itself on restart.
dock_app_urls=()
for app in "/Applications/Google Chrome.app" /Applications/kitty.app /Applications/Delta.app /Applications/Claude.app "/System/Applications/System Settings.app"; do
    [[ -d "${app}" ]] && dock_app_urls+=("file://${app// /%20}/")
done
current_dock_app_urls=()
dock_plist="$(defaults export com.apple.dock -)"
for ((i = 0; i < $(plutil -extract persistent-apps raw - <<<"${dock_plist}" 2>/dev/null || echo 0); i++)); do
    current_dock_app_urls+=("$(plutil -extract "persistent-apps.${i}.tile-data.file-data._CFURLString" raw - <<<"${dock_plist}")")
done
if [[ "${current_dock_app_urls[*]}" != "${dock_app_urls[*]}" ]]; then
    dock_tiles=()
    for url in "${dock_app_urls[@]}"; do
        dock_tiles+=("<dict><key>tile-type</key><string>file-tile</string><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${url}</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>")
    done
    defaults write com.apple.dock persistent-apps -array "${dock_tiles[@]}"
    macos_settings_changed=1
fi

# No window tiling when dragging to screen edges / holding Option, and no
# desktop widgets.
_macos_default com.apple.WindowManager EnableTilingByEdgeDrag -bool false
_macos_default com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false
_macos_default com.apple.WindowManager EnableTilingOptionAccelerator -bool false
_macos_default com.apple.WindowManager EnableTiledWindowMargins -bool false
_macos_default com.apple.WindowManager StandardHideWidgets -bool true
_macos_default com.apple.WindowManager StageManagerHideWidgets -bool true

# Free up Ctrl-Space and Ctrl-Option-Space (input source switching) for
# terminal use.
for hotkey in 60 61; do
    if [[ "$(defaults export com.apple.symbolichotkeys - | plutil -extract "AppleSymbolicHotKeys.${hotkey}.enabled" raw - 2>/dev/null)" != false ]]; then
        defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "${hotkey}" '<dict><key>enabled</key><false/></dict>'
        macos_settings_changed=1
    fi
done

# Caps Lock -> Control. System Settings stores this per keyboard, keyed by
# "<VendorID>-<ProductID>-0" (the built-in keyboard is "0-0-0" on Apple
# Silicon), and only applies it at login, so also apply it live via
# `hidutil`. HID usages: 0x700000039 is Caps Lock, 0x7000000E4 is Right Ctrl
# (which is what System Settings itself writes).
caps_lock_to_ctrl='{HIDKeyboardModifierMappingSrc=30064771129;HIDKeyboardModifierMappingDst=30064771300;}'
while read -r keyboard_id; do
    modifier_key="com.apple.keyboard.modifiermapping.${keyboard_id}"
    if ! defaults -currentHost read -g "${modifier_key}" 2>/dev/null | grep -q 'HIDKeyboardModifierMappingSrc = 30064771129'; then
        defaults -currentHost write -g "${modifier_key}" -array "${caps_lock_to_ctrl}"
    fi
done < <(ioreg -r -c AppleHIDKeyboardEventDriverV2 -l | awk -F' = ' '/"VendorID" =/{v=$2} /"ProductID" =/{print v "-" $2 "-0"}' | sort -u)
hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E4}]}' >/dev/null

if [[ -n "${macos_settings_changed}" ]]; then
    # Ask running apps to reload preferences (applies scroll direction and
    # hotkeys without logging out), then restart what caches its prefs.
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
    killall Dock || true
    killall WindowManager || true
fi
