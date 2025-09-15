#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nodePackages.npm curl jq nix-prefetch

set -euo pipefail

# Get the latest version from npm
version=$(npm view @musistudio/claude-code-router version)

if [ -z "$version" ]; then
    echo "Error: Could not fetch version from npm"
    exit 1
fi

echo "Latest version: $version"

# Get current version
current_version=$(grep -o 'version = "[^"]*"' default.nix | cut -d'"' -f2)
echo "Current version: $current_version"

if [ "$version" = "$current_version" ]; then
    echo "Already at latest version"
    exit 0
fi

# Get new hash
echo "Fetching new source hash..."
hash=$(nix-prefetch-url --unpack "https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-${version}.tgz")
sri_hash=$(nix hash convert --hash-algo sha256 "$hash")

echo "New hash: $sri_hash"

# Update version and hash in default.nix
sed -i "s/version = \"[^\"]*\"/version = \"$version\"/" default.nix
sed -i "s/hash = \"[^\"]*\"/hash = \"$sri_hash\"/" default.nix

echo "Updated claude-code-router to version $version" 