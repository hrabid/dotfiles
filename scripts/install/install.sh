#!/usr/bin/env bash

set -e

# List of CLI tools to install
TOOLS=(curl wget git neovim htop bat)

# Detect package manager
detect_package_manager() {
	if command -v dnf &>/dev/null; then
		echo "dnf"
	elif command -v apt &>/dev/null; then
		echo "apt"
	elif command -v pacman &>/dev/null; then
		echo "pacman"
	elif command -v zypper &>/dev/null; then
		echo "zypper"
	else
		echo "unsupported"
	fi
}

# Install packages using the appropriate package manager
install_packages() {
	local pm="$1"
	shift
	local packages=("$@")

	case "$pm" in
	dnf)
		sudo dnf install -y "${packages[@]}"
		;;
	apt)
		sudo apt update
		sudo apt install -y "${packages[@]}"
		;;
	pacman)
		sudo pacman -Sy --noconfirm "${packages[@]}"
		;;
	zypper)
		sudo zypper install -y "${packages[@]}"
		;;
	*)
		echo "Unsupported package manager: $pm"
		exit 1
		;;
	esac
}

# Handle special cases for certain tools
handle_special_cases() {
	local pm="$1"

	# Handle 'bat' installation
	if [[ " ${TOOLS[@]} " =~ " bat " ]]; then
		case "$pm" in
		apt)
			# On Debian/Ubuntu, 'bat' is installed as 'batcat' due to naming conflicts
			if ! command -v bat &>/dev/null && command -v batcat &>/dev/null; then
				mkdir -p ~/.local/bin
				ln -sf "$(command -v batcat)" ~/.local/bin/bat
				echo "Created symlink: ~/.local/bin/bat -> batcat"
				export PATH="$HOME/.local/bin:$PATH"
			fi
			;;
		*)
			# For other package managers, 'bat' is typically installed as 'bat'
			;;
		esac
	fi
}

# Optional: Install via Flatpak or Snap if the tool isn't available
install_via_flatpak_or_snap() {
	local tool="$1"

	if ! command -v "$tool" &>/dev/null; then
		if command -v flatpak &>/dev/null; then
			echo "Attempting to install $tool via Flatpak..."
			# Example: flatpak install -y flathub org.example.$tool
			# Replace 'org.example.$tool' with the actual Flatpak ID
		elif command -v snap &>/dev/null; then
			echo "Attempting to install $tool via Snap..."
			# Example: sudo snap install $tool
		else
			echo "Neither Flatpak nor Snap is available to install $tool."
		fi
	fi
}

main() {
	local pm
	pm=$(detect_package_manager)

	if [[ "$pm" == "unsupported" ]]; then
		echo "Unsupported package manager. Exiting."
		exit 1
	fi

	echo "Detected package manager: $pm"

	# Install packages
	install_packages "$pm" "${TOOLS[@]}"

	# Handle special cases
	handle_special_cases "$pm"

	# Optional: Attempt to install missing tools via Flatpak or Snap
	for tool in "${TOOLS[@]}"; do
		if ! command -v "$tool" &>/dev/null; then
			install_via_flatpak_or_snap "$tool"
		fi
	done
}

main "$@"
