#!/usr/bin/env bash

# Function to create desktop file for the browser selector
create_desktop_file() {
    local desktop_dir="$HOME/.local/share/applications"
    local desktop_file="$desktop_dir/browser-selector.desktop"
    
    # Create desktop directory if it doesn't exist
    mkdir -p "$desktop_dir"
    
    # Get the full path to this script
    local script_path=$(readlink -f "$0")
    
    # Create the desktop file
    cat > "$desktop_file" << EOF
[Desktop Entry]
Type=Application
Name=Browser Selector
GenericName=Web Browser
Comment=Choose a browser for each link you open
Exec="$script_path" %u
Icon=web-browser
Terminal=false
StartupNotify=true
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Exec="$script_path" %u

[Desktop Action new-private-window]
Name=New Private Window
Exec="$script_path" %u
EOF
    
    # Make it executable
    chmod +x "$desktop_file"
    
    echo "Desktop file created at: $desktop_file" >&2
    echo "You can now set Browser Selector as your default browser in system settings." >&2
    
    return 0
}

# Function to set as default browser
set_as_default_browser() {
    # First create/update the desktop file
    create_desktop_file
    
    # Set as default for common protocols using xdg-settings
    if command -v xdg-settings &> /dev/null; then
        echo "Setting Browser Selector as default browser..." >&2
        
        # Try to set as default browser
        if xdg-settings set default-web-browser browser-selector.desktop; then
            echo "Successfully set as default browser with xdg-settings." >&2
        else
            echo "Failed to set as default browser with xdg-settings." >&2
            echo "You may need to manually set it in your system settings." >&2
        fi
        
        # Set as handler for http and https
        for protocol in http https; do
            if xdg-mime default browser-selector.desktop x-scheme-handler/$protocol; then
                echo "Set as handler for $protocol links." >&2
            else 
                echo "Failed to set as handler for $protocol links." >&2
            fi
        done
    else
        echo "xdg-settings not found. Please set as default browser manually." >&2
        return 1
    fi
    
    return 0
}

# Check for special arguments
if [[ "$1" == "--install" ]]; then
    create_desktop_file
    exit 0
fi

if [[ "$1" == "--set-default" ]]; then
    set_as_default_browser
    exit 0
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cat << EOF
Browser Selector - Choose which browser to use for each link

Usage:
  $0 [OPTION] [URL]

Options:
  --install        Create desktop file to set as default browser
  --set-default    Create desktop file AND set as default browser
  --help, -h       Show this help message

Examples:
  $0 https://example.com    Open URL in selected browser
  $0 --install              Install as default browser option
  $0 --set-default          Set as the system default browser

Configuration:
  ~/.config/browser-selector/config.json

Report issues: https://github.com/yourusername/browser-selector
EOF
    exit 0
fi

LINK="$1"

# Config directory and file
CONFIG_DIR="$HOME/.config/browser-selector"
CONFIG_FILE="$CONFIG_DIR/config.json"
DEFAULT_CONFIG='{
  "last_browser": "",
  "blacklist": {
    "tracking_params": [
      "fbclid",
      "utm_source",
      "utm_medium",
      "utm_campaign",
      "utm_term",
      "utm_content",
      "gclid",
      "msclkid",
      "dclid",
      "zanpid",
      "igshid"
    ]
  },
  "display": {
    "max_domain_length": 50,
    "max_url_length": 80,
    "max_param_value_length": 50,
    "max_normal_params": 10,
    "max_blacklisted_params": 5
  }
}'

# Function to read a value from the config file using jq
read_config() {
    local key="$1"
    local default="$2"

    if [[ -f "$CONFIG_FILE" ]]; then
        local value
        value=$(jq -r "$key" "$CONFIG_FILE" 2>/dev/null)

        # Check if jq returned null or empty or error
        if [[ "$?" -ne 0 || "$value" == "null" || -z "$value" ]]; then
            echo "$default"
        else
            echo "$value"
        fi
    else
        echo "$default"
    fi
}

# Function to write a value to the config file using jq
write_config() {
    local key="$1"
    local value="$2"

    # Create a temporary file
    local temp_file
    temp_file=$(mktemp)

    # Update the value
    jq "$key = $value" "$CONFIG_FILE" > "$temp_file" 2>/dev/null

    # If successful, move the temp file to the config file
    if [[ "$?" -eq 0 ]]; then
        mv "$temp_file" "$CONFIG_FILE"
    else
        rm -f "$temp_file"
        echo "Error updating config file" >&2
        return 1
    fi

    return 0
}

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Create config file with defaults if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Creating default config file at $CONFIG_FILE" >&2
    echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
fi

# Check if jq is installed
if ! command -v jq &>/dev/null; then
    echo "Warning: jq is not installed. Using fallback configuration." >&2
    # Set default config values
    LAST_BROWSER=""
    PARAM_BLACKLIST=("fbclid" "utm_source" "utm_medium" "utm_campaign" "utm_term" "utm_content")
    MAX_DOMAIN_LENGTH=50
    MAX_LINK_LENGTH=80
    MAX_PARAM_VALUE_LENGTH=50
    MAX_NORMAL_PARAMS=10
    MAX_BLACKLISTED_PARAMS=5
else
    # Read config values
    LAST_BROWSER=$(read_config ".last_browser" "")

    # Read the blacklist parameters
    readarray -t PARAM_BLACKLIST < <(read_config ".blacklist.tracking_params[]" "fbclid")

    # Debug: show loaded blacklist
    echo "DEBUG: Loaded blacklist parameters: ${PARAM_BLACKLIST[*]}" >&2

    # Read display settings
    MAX_DOMAIN_LENGTH=$(read_config ".display.max_domain_length" 50)
    MAX_LINK_LENGTH=$(read_config ".display.max_url_length" 80)
    MAX_PARAM_VALUE_LENGTH=$(read_config ".display.max_param_value_length" 50)
    MAX_NORMAL_PARAMS=$(read_config ".display.max_normal_params" 10)
    MAX_BLACKLISTED_PARAMS=$(read_config ".display.max_blacklisted_params" 5)
fi

# Check if link is provided
if [[ -z "$LINK" ]]; then
    zenity --info \
      --title="Browser Selector" \
      --width=400 \
      --text="<b>Browser Selector</b>\n\n<i>No URL provided.</i>\n\nTo install as a default browser option:\n<tt>./select-browser.sh --install</tt>\n\nTo set as default browser:\n<tt>./select-browser.sh --set-default</tt>\n\nTo use directly:\n<tt>./select-browser.sh https://example.com</tt>"
    exit 1
fi

# Get domain from URL for display (just the domain, no path or query params)
DOMAIN=$(echo "$LINK" | sed -E 's|https?://([^/\?]+).*|\1|')

# Limit the length of domain and full URL for display
if [[ ${#DOMAIN} -gt $MAX_DOMAIN_LENGTH ]]; then
    DISPLAY_DOMAIN="${DOMAIN:0:$MAX_DOMAIN_LENGTH}..."
else
    DISPLAY_DOMAIN="$DOMAIN"
fi

if [[ ${#LINK} -gt $MAX_LINK_LENGTH ]]; then
    DISPLAY_LINK="${LINK:0:$MAX_LINK_LENGTH}..."
else
    DISPLAY_LINK="$LINK"
fi

# Global associative array to store desktop file paths.
declare -gA desktop_file_paths

# Function to detect installed browsers and output their info.
# It will also output the desktop file paths in a special format for later parsing.
detect_browsers() {
    local browsers=()
    local first_browser=true

    # Search paths for desktop files
    local search_paths=(
        "/usr/share/applications"
        "/usr/local/share/applications"
        "$HOME/.local/share/applications"
        "/var/lib/flatpak/exports/share/applications"
        "$HOME/.local/share/flatpak/exports/share/applications"
    )

    # Known browser desktop files and their display info
    declare -A browser_info=(
        ["firefox"]="🦊 Firefox|Mozilla Firefox web browser"
        ["firefox-esr"]="🦊 Firefox ESR|Mozilla Firefox Extended Support Release"
        ["org.mozilla.firefox"]="🦊 Firefox|Mozilla Firefox web browser (Flatpak)"
        ["google-chrome"]="🟢 Chrome|Google Chrome web browser"
        ["com.google.Chrome"]="🟢 Chrome|Google Chrome web browser (Flatpak)"
        ["chromium-browser"]="🔵 Chromium|Open-source web browser"
        ["chromium"]="🔵 Chromium|Open-source web browser"
        ["org.chromium.Chromium"]="🔵 Chromium|Open-source web browser (Flatpak)"
        ["vivaldi-stable"]="🔥 Vivaldi|Fast, customizable browser"
        ["vivaldi"]="🔥 Vivaldi|Fast, customizable browser"
        ["com.vivaldi.Vivaldi"]="🔥 Vivaldi|Fast, customizable browser (Flatpak)"
        ["opera"]="🔴 Opera|Feature-rich web browser"
        ["com.opera.Opera"]="🔴 Opera|Feature-rich web browser (Flatpak)"
        ["brave-browser"]="🦁 Brave|Privacy-focused web browser"
        ["com.brave.Browser"]="🦁 Brave|Privacy-focused web browser (Flatpak)"
        ["microsoft-edge"]="🔷 Edge|Microsoft Edge web browser"
        ["com.microsoft.Edge"]="🔷 Edge|Microsoft Edge web browser (Flatpak)"
        ["app.zen_browser.zen"]="🧘 Zen|Minimal Firefox-based browser"
        ["librewolf"]="🐺 LibreWolf|Privacy-focused Firefox fork"
        ["io.gitlab.librewolf-community"]="🐺 LibreWolf|Privacy-focused Firefox fork (Flatpak)"
        ["waterfox-g4"]="🌊 Waterfox|Privacy-focused Firefox fork"
        ["epiphany"]="🌐 Web|GNOME Web browser"
        ["org.gnome.Epiphany"]="🌐 Web|GNOME Web browser (Flatpak)"
        ["konqueror"]="🐉 Konqueror|KDE web browser"
        ["org.kde.konqueror"]="🐉 Konqueror|KDE web browser (Flatpak)"
        ["falkon"]="🦅 Falkon|Lightweight Qt web browser"
        ["org.kde.falkon"]="🦅 Falkon|Lightweight Qt web browser (Flatpak)"
        ["qutebrowser"]="⌨️ qutebrowser|Keyboard-driven web browser"
        ["org.qutebrowser.qutebrowser"]="⌨️ qutebrowser|Keyboard-driven web browser (Flatpak)"
        ["surf"]="🏄 Surf|Simple web browser"
        ["midori"]="🌸 Midori|Lightweight web browser"
        ["org.midori_browser.Midori"]="🌸 Midori|Lightweight web browser (Flatpak)"
        ["dillo"]="🐛 Dillo|Very lightweight web browser"
        ["netsurf-gtk"]="🌐 NetSurf|Lightweight web browser"
        ["org.netsurf.NetSurf"]="🌐 NetSurf|Lightweight web browser (Flatpak)"
    )

    # Arrays to temporarily hold output for browsers and desktop file assignments
    local browser_output=()
    local desktop_file_assignments=()
    local first_browser=true  # Default first browser to true initially

    # If we have a last choice, we'll mark it TRUE and all others FALSE
    # If no last choice, we'll mark the first one TRUE

    # Search for browser desktop files
    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]]; then
            for desktop_file in "$path"/*.desktop; do
                if [[ -f "$desktop_file" ]]; then
                    local basename=$(basename "$desktop_file" .desktop)

                    # Check if this is a known browser
                    if [[ -n "${browser_info[$basename]}" ]]; then
                        # Extract executable from desktop file
                        local exec_line=$(grep "^Exec=" "$desktop_file" | head -1)
                        if [[ -n "$exec_line" ]]; then
                            # Skip if already added (check against the list to be outputted)
                            local already_added=false
                            for ((i=2; i<${#browser_output[@]}; i+=4)); do
                                if [[ "${browser_output[i]}" == "$basename" ]]; then
                                    already_added=true
                                    break
                                fi
                            done

                            if [[ "$already_added" == false ]]; then
                                local info="${browser_info[$basename]}"
                                local icon_name="${info%%|*}"
                                local description="${info##*|}"

                                # Prepare the assignment string for the global array.
                                # IMPORTANT: Quote the desktop_file variable to handle spaces/special characters correctly.
                                desktop_file_assignments+=("desktop_file_paths[\"$basename\"]=\"$desktop_file\"")

                                # Set TRUE if this matches last used browser or if it's the first one and we have no last choice
                                if [[ "$basename" == "$LAST_BROWSER" ]]; then
                                    browser_output+=("TRUE")
                                    first_browser=false  # No longer need to mark first browser as true
                                elif [[ "$first_browser" == true && -z "$LAST_BROWSER" ]]; then
                                    browser_output+=("TRUE")
                                    first_browser=false
                                else
                                    browser_output+=("FALSE")
                                fi
                                browser_output+=("$icon_name")       # Column 2: Display name with icon
                                browser_output+=("$basename")        # Column 3: Desktop file ID (hidden, returned)
                                browser_output+=("$description")     # Column 4: Description
                            fi
                        fi
                    fi
                    # For debugging - uncomment to see all desktop files
                    # echo "DEBUG: Checking desktop file: $desktop_file (basename: $basename)" >&2
                fi
            done
        fi
    done

    # Output the browser info for zenity
    printf '%s\n' "${browser_output[@]}"

    # Output the desktop file assignments in a special format, prefixed to distinguish
    for assignment in "${desktop_file_assignments[@]}"; do
        echo "__DESKTOP_PATH_ASSIGNMENT__$assignment"
    done
}

# Get available browsers and store desktop file paths
readarray -t RAW_BROWSERS_OUTPUT < <(detect_browsers)

# Echo the last browser choice for debugging
if [[ -n "$LAST_BROWSER" ]]; then
    echo "Last used browser: $LAST_BROWSER" >&2
fi

# Initialize array for Zenity and process desktop file paths
BROWSERS_ARRAY=()
for line in "${RAW_BROWSERS_OUTPUT[@]}"; do
    if [[ "$line" == "__DESKTOP_PATH_ASSIGNMENT__"* ]]; then
        # Evaluate the assignment in the current shell
        # Ensure the string passed to eval is correct for assignments
        eval "${line#__DESKTOP_PATH_ASSIGNMENT__}"
    else
        # Add to the array for Zenity
        BROWSERS_ARRAY+=("$line")
    fi
done

# Check if any browsers were found (based on the Zenity output part)
if [[ ${#BROWSERS_ARRAY[@]} -eq 0 ]]; then
    zenity --error \
      --text="<b>No supported browsers found!</b>\n\nPlease install a web browser first." \
      --title="Browser Selector" \
      --width=350
    exit 1
fi

# Function to check if a parameter is blacklisted
is_blacklisted() {
    local param_name="$1"
    for blacklisted in "${PARAM_BLACKLIST[@]}"; do
        if [[ "$param_name" == "$blacklisted" || "$param_name" == "$blacklisted"* ]]; then
            return 0  # True, parameter is blacklisted
        fi
    done
    return 1  # False, parameter is not blacklisted
}

# Parse URL to extract query parameters for display
# Make sure to escape ampersands for zenity markup
ESCAPED_DOMAIN="${DISPLAY_DOMAIN//&/&amp;}"
ESCAPED_LINK="${DISPLAY_LINK//&/&amp;}"
DISPLAY_TEXT="<big><b>Choose your browser</b></big>\n\n<b>URL:</b> <i>$ESCAPED_DOMAIN</i>\n<small>$ESCAPED_LINK</small>"

# Check if URL has query parameters and extract them
if [[ "$LINK" == *\?* ]]; then
    QUERY_STRING="${LINK#*\?}"
    if [[ -n "$QUERY_STRING" ]]; then
        # Array to store all parameters
        declare -a ALL_PARAMS=()
        declare -a BLACKLISTED_COUNT=0
        declare -a NORMAL_COUNT=0

        # Parse parameters
        IFS='&' read -ra PARAMS <<< "$QUERY_STRING"
        for param in "${PARAMS[@]}"; do
            PARAM_NAME="${param%%=*}"
            PARAM_VALUE="${param#*=}"

            # Limit parameter value length
            if [[ ${#PARAM_VALUE} -gt $MAX_PARAM_VALUE_LENGTH ]]; then
                PARAM_VALUE="${PARAM_VALUE:0:$MAX_PARAM_VALUE_LENGTH}..."
            fi

            # URL decode the value for better display
            PARAM_VALUE=$(echo -e "${PARAM_VALUE//%/\\x}")

            # Escape ampersands for zenity markup
            ESCAPED_PARAM_NAME="${PARAM_NAME//&/&amp;}"
            ESCAPED_PARAM_VALUE="${PARAM_VALUE//&/&amp;}"

            # Format parameter based on whether it's blacklisted
            if is_blacklisted "$PARAM_NAME"; then
                # Add with strikethrough and gray color (using pango markup)
                echo "DEBUG: Parameter '$PARAM_NAME' is blacklisted" >&2
                # Using standard Pango markup for strikethrough
                ALL_PARAMS+=("<span strikethrough='true' alpha='50%'>$ESCAPED_PARAM_NAME = $ESCAPED_PARAM_VALUE</span>")
                ((BLACKLISTED_COUNT++))
            else
                # Add normal parameter
                echo "DEBUG: Parameter '$PARAM_NAME' is NOT blacklisted" >&2
                ALL_PARAMS+=("$ESCAPED_PARAM_NAME = $ESCAPED_PARAM_VALUE")
                ((NORMAL_COUNT++))
            fi
        done

        # Add parameters section
        if [[ ${#ALL_PARAMS[@]} -gt 0 ]]; then
            # Include count of normal and filtered parameters in the header
            if [[ $BLACKLISTED_COUNT -gt 0 ]]; then
                DISPLAY_TEXT+="\n\n<b>Parameters</b> <small>($NORMAL_COUNT active, $BLACKLISTED_COUNT filtered)</small>:"
                DISPLAY_TEXT+="\n<small><i>Note: <span strikethrough='true' alpha='60%'>Strikethrough items</span> are tracking parameters that will be filtered.</i></small>"
            else
                DISPLAY_TEXT+="\n\n<b>Parameters</b> <small>($NORMAL_COUNT)</small>:"
            fi

            # Limit the number of parameters to display
            PARAM_COUNT=0
            MAX_DISPLAY_PARAMS=$((MAX_NORMAL_PARAMS + MAX_BLACKLISTED_PARAMS))  # Show more total params

            for param_text in "${ALL_PARAMS[@]}"; do
                ((PARAM_COUNT++))

                # Check if we've reached the limit
                if [[ $PARAM_COUNT -gt $MAX_DISPLAY_PARAMS ]]; then
                    REMAINING=$((${#ALL_PARAMS[@]} - MAX_DISPLAY_PARAMS))
                    DISPLAY_TEXT+="\n<small>... and $REMAINING more parameters</small>"
                    break
                fi

                DISPLAY_TEXT+="\n<small>• $param_text</small>"
            done
        fi
    fi
fi

# Enhanced zenity dialog with detected browsers
echo "DEBUG DISPLAY TEXT START" >&2
echo "$DISPLAY_TEXT" >&2
echo "DEBUG DISPLAY TEXT END" >&2

BROWSER=$(zenity --list \
  --title="🌐 Browser Selector" \
  --text="$DISPLAY_TEXT" \
  --radiolist \
  --column="" \
  --column="Browser" \
  --column="ID" \
  --column="Description" \
  --width=700 \
  --height=500 \
  --ok-label="🚀 Open" \
  --cancel-label="❌ Cancel" \
  --hide-column=3 \
  --print-column=3 \
  "${BROWSERS_ARRAY[@]}")

# Check if user cancelled
if [[ $? -ne 0 ]]; then
    notify-send "Browser Selector" "Cancelled by user" --icon=dialog-information
    exit 0
fi

# Launch selected browser
if [[ -n "$BROWSER" ]]; then
    # Debug: Show what was selected
    echo "Selected browser: $BROWSER" >&2

    # Save the selection for next time
    if command -v jq &>/dev/null; then
        write_config ".last_browser" "\"$BROWSER\""
    else
        # Fallback if jq is not available
        echo "$BROWSER" > "$CONFIG_DIR/last_choice"
    fi

    # Remove 'local' keyword here, as this is in the main script body
    desktop_file="${desktop_file_paths[$BROWSER]}"

    # Check if we have the desktop file path stored
    if [[ -n "$desktop_file" ]]; then # Check if the variable itself is non-empty
        echo "Desktop file: $desktop_file" >&2

        # Remove 'local' keyword here
        browser_name=$(grep "^Name=" "$desktop_file" | head -1 | sed 's/^Name=//')
        [[ -z "$browser_name" ]] && browser_name="$BROWSER"

        # Show notification
        notify-send "Browser Selector" "🚀 Opening link in $browser_name..." \
          --icon=web-browser \
          --hint=int:transient:1 \
          --expire-time=3000

        # Try multiple launch methods
        if command -v gtk-launch &> /dev/null; then
            echo "Trying gtk-launch..." >&2
            # gtk-launch is the most robust for desktop files, especially Flatpaks
            gtk-launch "$BROWSER" "$LINK" &
        elif command -v gio &> /dev/null; then
            echo "Trying gio launch..." >&2
            # gio launch also handles desktop files and can be good for Flatpaks
            gio launch "$desktop_file" "$LINK" &
        else
            echo "Trying direct exec..." >&2
            # Fallback to direct execution for non-Flatpak apps primarily
            # This logic might struggle with complex Flatpak `Exec` lines
            exec_line=$(grep "^Exec=" "$desktop_file" | head -1 | sed 's/^Exec=//')
            exec_line=$(echo "$exec_line" | sed "s/%[uUfF]/$LINK/g")
            exec_line=$(echo "$exec_line" | sed 's/%[a-zA-Z]//g') # Remove any remaining %x parameters
            echo "Executing: $exec_line" >&2
            eval "$exec_line" &
        fi

        # Success notification
        sleep 1
        notify-send "Browser Selector" "✅ Browser launched successfully!" \
          --icon=dialog-information \
          --hint=int:transient:1 \
          --expire-time=2000
    else
        echo "No desktop file path found for: $BROWSER (variable was empty)" >&2
        echo "Available keys in desktop_file_paths: ${!desktop_file_paths[@]}" >&2
        zenity --error \
          --text="<b>Error:</b> Could not find desktop file for $BROWSER" \
          --title="Browser Selector" \
          --width=350
    fi
fi
