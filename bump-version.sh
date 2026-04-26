#!/bin/bash
#
# bump-version.sh
# Increments MARKETING_VERSION across all Clarity targets in the Xcode project.
#
# Usage:
#   ./bump-version.sh major   # 1.7.0 → 2.0.0
#   ./bump-version.sh minor   # 1.7.0 → 1.8.0
#   ./bump-version.sh patch   # 1.7.0 → 1.7.1
#   ./bump-version.sh build   # increments CURRENT_PROJECT_VERSION only

set -euo pipefail

PBXPROJ="Clarity.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
    echo "Error: $PBXPROJ not found. Run this script from the Clarity project root." >&2
    exit 1
fi

COMPONENT="${1:-}"

if [[ -z "$COMPONENT" ]]; then
    echo "Usage: $0 <major|minor|patch|build>" >&2
    exit 1
fi

# Read current versions
CURRENT_MARKETING=$(grep -m1 'MARKETING_VERSION' "$PBXPROJ" | sed 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/' | tr -d '[:space:]')
CURRENT_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | sed 's/.*CURRENT_PROJECT_VERSION = \([^;]*\);.*/\1/' | tr -d '[:space:]')

if [[ -z "$CURRENT_MARKETING" ]]; then
    echo "Error: Could not read MARKETING_VERSION from $PBXPROJ" >&2
    exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_MARKETING"

case "$COMPONENT" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    build)
        NEW_BUILD=$((CURRENT_BUILD + 1))
        echo "Bumping build number: $CURRENT_BUILD → $NEW_BUILD"
        sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ"
        echo "Done. Build number is now $NEW_BUILD."
        exit 0
        ;;
    *)
        echo "Error: Unknown component '$COMPONENT'. Use major, minor, patch, or build." >&2
        exit 1
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo "Bumping version: $CURRENT_MARKETING → $NEW_VERSION"
sed -i '' "s/MARKETING_VERSION = $CURRENT_MARKETING;/MARKETING_VERSION = $NEW_VERSION;/g" "$PBXPROJ"
echo "Done. Marketing version is now $NEW_VERSION."
