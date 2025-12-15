detect_os() {
  if [ -f /etc/os-release ]; then
    # Most modern Linux distros use this file
    . /etc/os-release
    echo "OS: $NAME"
    echo "Version: $VERSION"
  elif type lsb_release >/dev/null 2>&1; then
    # Older distros with LSB support
    echo "OS: $(lsb_release -si)"
    echo "Version: $(lsb_release -sr)"
  elif [ -f /etc/lsb-release ]; then
    # Debian-based systems
    . /etc/lsb-release
    echo "OS: $DISTRIB_ID"
    echo "Version: $DISTRIB_RELEASE"
  elif [ -f /etc/debian_version ]; then
    echo "OS: Debian"
    echo "Version: $(cat /etc/debian_version)"
  elif [ -f /etc/redhat-release ]; then
    echo "OS: Red Hat"
    echo "Version: $(cat /etc/redhat-release)"
  elif [ "$(uname)" = "Darwin" ]; then
    echo "OS: macOS"
    echo "Version: $(sw_vers -productVersion)"
  elif [ "$(uname -o)" = "Android" ]; then
    echo "OS: Android"
    echo "Version: $(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')"
  else
    echo "OS: $(uname -s)"
    echo "Version: $(uname -r)"
  fi
}
detect_os
