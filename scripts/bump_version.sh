#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_root="$(cd "$script_dir/.." && pwd)"
version_file="$package_root/VERSION"
source_file="$package_root/Sources/LearningDomainKit/LearningDomainKitVersion.swift"
bump_type="${1:-patch}"

if [[ ! -f "$version_file" ]]; then
  echo "Missing VERSION file at $version_file" >&2
  exit 1
fi

current_version="$(tr -d '[:space:]' < "$version_file")"
if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid current version in VERSION: $current_version" >&2
  exit 1
fi

IFS='.' read -r major minor patch <<< "$current_version"

case "$bump_type" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
  *)
    echo "Usage: $0 [major|minor|patch]" >&2
    exit 1
    ;;
esac

next_version="${major}.${minor}.${patch}"

printf "%s\n" "$next_version" > "$version_file"
cat > "$source_file" <<EOF
import Foundation

public enum LearningDomainKitVersion {
    public static let current = "$next_version"
}
EOF

echo "Updated LearningDomainKit version: $current_version -> $next_version"
