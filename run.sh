#!/usr/bin/env bash
set -euo pipefail

# This script is rendered as a template by Terraform
# SOURCE_DIR and TARGET_DIR are injected at render time
# These use single '$' because we WANT Terraform to replace them
SOURCE_DIR="${SOURCE_DIR}"
TARGET_DIR="${TARGET_DIR}"

# Seed user home from persistent /coder/home when needed.
seed_from_persistent() {
	# FIX: Use '$$' to escape Bash variables so Terraform ignores them
	src_root="$${SOURCE_DIR:-/coder/home}"
	tgt_root="$${TARGET_DIR:-$HOME}"

	if [ -z "$tgt_root" ]; then tgt_root="$HOME"; fi
	if [ ! -d "$src_root" ]; then
		return
	fi
	echo "Seeding user home from $src_root to $tgt_root"
	mkdir -p "$tgt_root"

	# If running as root, ensure the target directory is owned by the intended user
	# before attempting rsync operations
	if [ "$(id -u)" -eq 0 ]; then
		target_user="$${SUDO_USER:-$(logname 2>/dev/null || echo embold)}"
		# Force ownership of the target root to prevent permission denied errors
		chown -R "$target_user:$target_user" "$tgt_root" 2>/dev/null || true
		chmod -R u+rwX,g-rwx,o-rwx "$tgt_root" 2>/dev/null || true
	fi

	# Helper to rsync a source subdir into target (ignore existing files)
	rsync_subdir() {
		local s="$1" t="$2"
		if [ -d "$s" ]; then
			mkdir -p "$t"
			if [ "$(id -u)" -eq 0 ]; then
				# If running as root, prefer to chown copied files to the target user
				# FIX: Escape SUDO_USER with $$
				target_user="$${SUDO_USER:-$(logname 2>/dev/null || echo embold)}"
				echo "Copying $s -> $t (chown -> $target_user)"
				rsync -aH --ignore-existing --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r --chown="$target_user:$target_user" "$s/" "$t/" || true
			else
				echo "Copying $s -> $t"
				rsync -aH --ignore-existing "$s/" "$t/" || true
			fi
		fi
	}

	rsync_subdir "$src_root/.local" "$tgt_root/.local"
	rsync_subdir "$src_root/.fnm" "$tgt_root/.fnm"
	rsync_subdir "$src_root/.cache/oh-my-posh/themes" "$tgt_root/.cache/oh-my-posh/themes"
	rsync_subdir "$src_root/.config/antidote" "$tgt_root/.config/antidote"

	# Ensure ownership and basic perms are correct for target
	if [ "$(id -u)" -eq 0 ]; then
		# FIX: Escape SUDO_USER with $$
		target_user="$${SUDO_USER:-$(logname 2>/dev/null || echo embold)}"
		chown -R "$target_user:$target_user" "$tgt_root" || true
	fi
}

# Ensure image-provided gems for the current Ruby version are visible
seed_gems_env() {
	# Detect the ruby version if ruby is available
	if command -v ruby >/dev/null 2>&1; then
		ruby_ver=$(ruby -e 'print RUBY_VERSION' 2>/dev/null || true)
	else
		ruby_ver=""
	fi

	if [ -z "$ruby_ver" ]; then
		return
	fi

	coder_gems_dir="/coder/gems/ruby/$ruby_ver"
	if [ ! -d "$coder_gems_dir" ]; then
		return
	fi

	profile_dir="$HOME/.profile.d"
	mkdir -p "$profile_dir"
	snippet="$profile_dir/embold-image-gems.sh"
	if [ -f "$snippet" ]; then
		return
	fi

	cat >"$snippet" <<'EOF'
# embold: expose image-provided gems for this Ruby version
if [ -d "/coder/gems/ruby/REPLACE_RUBY_VER" ]; then
  export GEM_PATH="$GEM_PATH:/coder/gems/ruby/REPLACE_RUBY_VER"
  export PATH="$PATH:/coder/gems/ruby/REPLACE_RUBY_VER/bin"
fi
EOF

	# Replace placeholder with detected ruby_ver
	sed -i "s/REPLACE_RUBY_VER/$ruby_ver/g" "$snippet" || true

	# Ensure snippet is readable and owned by the user when running as root
	if [ "$(id -u)" -eq 0 ]; then
		target_user="$${SUDO_USER:-$(logname 2>/dev/null || echo embold)}"
		chown "$target_user:$target_user" "$snippet" || true
		chmod 0644 "$snippet" || true
	else
		chmod 0644 "$snippet" || true
	fi
}

# Run seeding early so later initialization (dotfiles, gems) sees provided files
seed_from_persistent
seed_gems_env

ensure_oh_my_posh() {
	if command -v oh-my-posh >/dev/null 2>&1; then
		return
	fi

	install_dir="$HOME/.local/bin"
	themes_dir="$HOME/.cache/oh-my-posh/themes"
	mkdir -p "$install_dir" "$themes_dir"

	# Prefer to reuse an existing binary installed at /coder/home
	if [ -x "/coder/home/.local/bin/oh-my-posh" ]; then
		echo "Copying oh-my-posh binary from /coder/home into $install_dir"
		cp -a /coder/home/.local/bin/oh-my-posh "$install_dir/" || true
		chmod +x "$install_dir/oh-my-posh" || true
		return
	fi

	# Attempt user-local install via official installer script
	echo "Installing oh-my-posh into $install_dir"
	if curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$install_dir" -t "$themes_dir"; then
		echo "oh-my-posh installed to $install_dir"
	else
		echo "oh-my-posh install failed or network unavailable; continuing without it"
	fi

	# If running as root during container init, ensure ownership of copied files
	if [ "$(id -u)" -eq 0 ]; then
		target_user="$${SUDO_USER:-$(logname 2>/dev/null || echo embold)}"
		chown -R "$target_user:$target_user" "$HOME/.local" "$HOME/.cache/oh-my-posh" || true
	fi
}

ensure_oh_my_posh
