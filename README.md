# 🌐 Browser Selector

A smart browser selection tool for Linux that lets you choose which browser to open each link with. Perfect for users who have multiple browsers installed and want to pick the right one for each situation.

## ✨ Features

- **Interactive Browser Selection**: Choose from all installed browsers with a beautiful GUI dialog
- **Smart Browser Detection**: Automatically detects browsers from various installation methods (native packages, Flatpak, Snap)
- **URL Parameter Filtering**: Automatically identifies and filters tracking parameters (utm_*, fbclid, etc.)
- **Remember Last Choice**: Remembers your last browser selection for convenience
- **System Integration**: Can be set as your default browser to intercept all web links
- **Rich URL Preview**: Shows domain, full URL, and query parameters with visual indicators
- **Configurable**: JSON configuration file for customizing behavior and display settings

## 🔧 Requirements

- **Required**: `zenity` (for GUI dialogs)
- **Required**: `jq` (for JSON configuration handling)
- **Optional**: `notify-send` (for desktop notifications)
- **Optional**: `gtk-launch` or `gio` (for better browser launching)

### Installing Dependencies

**Ubuntu/Debian:**

```bash
sudo apt update
sudo apt install zenity jq libnotify-bin
```

**Fedora/RHEL:**

```bash
sudo dnf install zenity jq libnotify
```

**Arch Linux:**

```bash
sudo pacman -S zenity jq libnotify
```

**openSUSE:**

```bash
sudo zypper install zenity jq libnotify-tools
```

## 📥 Installation

### Quick Installation

1. **Download the script:**

   ```bash
   wget https://raw.githubusercontent.com/yourusername/browser-selector/main/select-browser.sh
   # or
   curl -O https://raw.githubusercontent.com/yourusername/browser-selector/main/select-browser.sh
   ```

2. **Make it executable:**

   ```bash
   chmod +x select-browser.sh
   ```

3. **Install as default browser option:**

   ```bash
   ./select-browser.sh --install
   ```

4. **Set as system default browser:**

   ```bash
   ./select-browser.sh --set-default
   ```

### Manual Installation

1. **Clone or download the repository:**

   ```bash
   git clone https://github.com/yourusername/browser-selector.git
   cd browser-selector
   ```

2. **Make the script executable:**

   ```bash
   chmod +x select-browser.sh
   ```

3. **Create desktop integration:**

   ```bash
   ./select-browser.sh --install
   ```

4. **Set as default browser (optional):**

   ```bash
   ./select-browser.sh --set-default
   ```

### System-wide Installation

For system-wide availability:

```bash
# Copy to system location
sudo cp select-browser.sh /usr/local/bin/browser-selector
sudo chmod +x /usr/local/bin/browser-selector

# Install desktop file
/usr/local/bin/browser-selector --install

# Set as default browser
/usr/local/bin/browser-selector --set-default
```

## 🚀 Usage

### Command Line Options

```bash
# Show help
./select-browser.sh --help

# Open a URL (shows browser selection dialog)
./select-browser.sh https://example.com

# Install desktop file (adds to applications menu)
./select-browser.sh --install

# Set as system default browser
./select-browser.sh --set-default
```

### Setting as Default Browser

After running `--set-default`, you may need to:

1. **GNOME/Ubuntu**: Go to Settings → Default Applications → Web Browser
2. **KDE/Plasma**: Go to System Settings → Default Applications → Web Browser
3. **XFCE**: Go to Settings → Preferred Applications → Web Browser
4. **Other DEs**: Look for "Default Applications" or "Preferred Applications" in system settings

Select "Browser Selector" from the list.

## ⚙️ Configuration

The script creates a configuration file at `~/.config/browser-selector/config.json` with the following structure:

```json
{
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
}
```

### Customizing Tracking Parameter Filters

Edit the `tracking_params` array to add or remove URL parameters that should be highlighted as tracking parameters:

```json
{
  "blacklist": {
    "tracking_params": [
      "fbclid",
      "utm_source",
      "custom_tracker",
      "ref"
    ]
  }
}
```

### Adjusting Display Settings

Modify the `display` section to change how URLs and parameters are shown:

- `max_domain_length`: Maximum characters to show for domain names
- `max_url_length`: Maximum characters to show for full URLs
- `max_param_value_length`: Maximum characters to show for parameter values
- `max_normal_params`: Maximum normal parameters to display
- `max_blacklisted_params`: Maximum tracking parameters to display

## 🌐 Supported Browsers

The script automatically detects and supports:

### Popular Browsers

- 🦊 **Firefox** (Mozilla Firefox)
- 🟢 **Google Chrome**
- 🔵 **Chromium**
- 🔥 **Vivaldi**
- 🔴 **Opera**
- 🦁 **Brave**
- 🔷 **Microsoft Edge**

### Privacy-Focused Browsers

- 🧘 **Zen Browser**
- 🐺 **LibreWolf**
- 🌊 **Waterfox**

### Lightweight Browsers

- 🌐 **GNOME Web** (Epiphany)
- 🦅 **Falkon**
- ⌨️ **qutebrowser**
- 🏄 **Surf**
- 🌸 **Midori**
- 🐛 **Dillo**
- 🌐 **NetSurf**

### Desktop Environment Browsers

- 🐉 **Konqueror** (KDE)

The script supports browsers installed via:

- **Native packages** (apt, dnf, pacman, etc.)
- **Flatpak** applications
- **Snap** packages (limited support)

## 🔍 Features in Detail

### URL Parameter Analysis

- **Visual Indicators**: Tracking parameters are shown with strikethrough text
- **Parameter Limiting**: Long parameter lists are truncated for readability
- **Smart Parsing**: Handles complex URLs with multiple parameters

### Browser Detection

- **Multi-source Detection**: Scans system and user application directories
- **Format Support**: Handles various desktop file formats and locations
- **Flatpak Integration**: Special support for Flatpak applications

### Memory and Preferences

- **Last Choice Memory**: Remembers your last browser selection
- **Persistent Config**: Settings stored in JSON format
- **Fallback Support**: Works even without jq (with limited functionality)

## 🐛 Troubleshooting

### Browser Not Detected

If your browser isn't showing up:

1. Check if it has a desktop file:

   ```bash
   find /usr/share/applications ~/.local/share/applications -name "*browser*" -o -name "*chrome*" -o -name "*firefox*"
   ```

2. Verify the desktop file has an `Exec=` line:

   ```bash
   grep "Exec=" /path/to/browser.desktop
   ```

### Can't Set as Default Browser

If the `--set-default` option doesn't work:

1. Manually set in system settings (see Usage section)
2. Check if xdg-settings is installed:

   ```bash
   which xdg-settings
   ```

### Launches Wrong Browser

If the wrong browser opens:

1. Check desktop file permissions:

   ```bash
   ls -la ~/.local/share/applications/browser-selector.desktop
   ```

2. Verify the desktop file content:

   ```bash
   cat ~/.local/share/applications/browser-selector.desktop
   ```

### Configuration Issues

If configuration isn't working:

1. Check if jq is installed:

   ```bash
   which jq
   ```

2. Verify config file format:

   ```bash
   jq . ~/.config/browser-selector/config.json
   ```

3. Reset configuration:

   ```bash
   rm ~/.config/browser-selector/config.json
   ./select-browser.sh https://example.com  # Will recreate defaults
   ```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

### Adding Browser Support

To add support for a new browser, edit the `browser_info` associative array in the script:

```bash
["browser-desktop-id"]="🎨 Display Name|Description text"
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Thanks to the Zenity project for the GUI dialogs
- Thanks to the jq project for JSON processing
- Inspired by the need for better browser management on Linux desktops
