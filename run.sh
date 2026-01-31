#!/usr/bin/env bash
set -euo pipefail

# These use single '$' because we WANT Terraform to replace them
SOURCE_DIR="${SOURCE_DIR}"
TARGET_DIR="${TARGET_DIR}"
TARGET_USER="${TARGET_USER}"

# Seed user home from persistent /coder/home when needed.
seed_from_persistent() {
	# Use '$$' to escape Bash variables so Terraform ignores them
	src_root="$${SOURCE_DIR:-/coder/home}"
	tgt_root="$${TARGET_DIR:-$HOME}"
	target_user="$${TARGET_USER:-embold}"

	if [ ! -d "$src_root" ]; then return; fi

	SUDO=""
	if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

	# Standard system directories for tools
	$SUDO mkdir -p "$tgt_root/.local/bin" \
		"$tgt_root/.cache/antidote" \
		"$tgt_root/.fnm" \
		"$tgt_root/.gem/ruby" \
		"$tgt_root/.cache/oh-my-posh/themes"

	# Build the list of directories that actually exist in the source
	local sync_list=()
	local potential_dirs=(
		".local"
	)

	for dir in "$${potential_dirs[@]}"; do
		if [ -d "$src_root/$dir" ]; then
			sync_list+=("$src_root/$dir")
		fi
	done

	if [ "$${#sync_list[@]}" -gt 0 ]; then
	echo "⏳ Seeding $${#sync_list[@]} directories..."
		local rsync_flags="-aH --ignore-existing --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r --chown=$target_user:$target_user"


		$SUDO rsync $rsync_flags "$${sync_list[@]}" "$tgt_root/" || true
	fi

	# Migration: Move legacy .gems to .gem
	if [ -d "$tgt_root/.gems" ] && [ ! -d "$tgt_root/.gem" ]; then
		echo "🚚 Migrating legacy .gems to .gem"
		$SUDO mv "$tgt_root/.gems" "$tgt_root/.gem" || true
	fi
}

seed_from_persistent

# Final ownership check
target_user="$${TARGET_USER:-embold}"
sudo chown -R "$target_user:$target_user" "$HOME" 2>/dev/null || true
