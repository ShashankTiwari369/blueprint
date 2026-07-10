#!/bin/bash
# Blueprint — Install Script
# Copies Blueprint skills into your Claude Code skills directory.
# Run once. Re-run to update after pulling new versions.

set -e

SKILLS_DIR="$HOME/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Blueprint PM Skills — Installer"
echo "─────────────────────────────────────────"

# Create skills directory if it doesn't exist
mkdir -p "$SKILLS_DIR"

# Install each skill
INSTALLED=0
for skill_dir in "$SCRIPT_DIR/.claude/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  mkdir -p "$SKILLS_DIR/$skill_name"
  cp "$skill_dir/SKILL.md" "$SKILLS_DIR/$skill_name/SKILL.md"
  echo "  ✓ $skill_name"
  INSTALLED=$((INSTALLED + 1))
done

echo ""
echo "$INSTALLED skills installed to $SKILLS_DIR"
echo ""
echo "Next steps:"
echo "  1. Copy the context template to any project where you'll use Blueprint:"
echo "     cp $SCRIPT_DIR/pm-context.yml.example /path/to/your/project/pm-context.yml"
echo ""
echo "  2. Fill in your company, product, personas, and baseline metrics."
echo ""
echo "  3. Open Claude Code in your project directory and run:"
echo "     /pm:init"
echo ""
echo "Blueprint is ready."
