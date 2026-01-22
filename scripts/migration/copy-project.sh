#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
SOURCE=""
DEST=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --source)
      SOURCE="$2"
      shift 2
      ;;
    --dest)
      DEST="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown parameter: $1${NC}"
      echo "Usage: $0 --source <source-path> --dest <dest-path>"
      exit 1
      ;;
  esac
done

# Validate arguments
if [[ -z "$SOURCE" || -z "$DEST" ]]; then
  echo -e "${RED}Error: Both --source and --dest are required${NC}"
  echo "Usage: $0 --source <source-path> --dest <dest-path>"
  exit 1
fi

# Check if source exists
if [[ ! -d "$SOURCE" ]]; then
  echo -e "${RED}Error: Source directory does not exist: $SOURCE${NC}"
  exit 1
fi

# Warn if dest exists
if [[ -d "$DEST" ]]; then
  echo -e "${YELLOW}Warning: Destination directory already exists: $DEST${NC}"
  read -p "Do you want to overwrite it? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Aborted.${NC}"
    exit 0
  fi
  rm -rf "$DEST"
fi

# Extract project name
PROJECT_NAME=$(basename "$DEST")

echo -e "${BLUE}📦 Copying $PROJECT_NAME...${NC}"

# Create destination directory
mkdir -p "$DEST"

# Copy with rsync, excluding common directories
rsync -a --progress \
  --exclude='node_modules/' \
  --exclude='.git/' \
  --exclude='dist/' \
  --exclude='build/' \
  --exclude='.next/' \
  --exclude='.turbo/' \
  --exclude='coverage/' \
  --exclude='.pnpm-store/' \
  --exclude='.cache/' \
  --exclude='.vite/' \
  --exclude='*.log' \
  "$SOURCE/" "$DEST/"

# Get statistics
FILE_COUNT=$(find "$DEST" -type f | wc -l | tr -d ' ')
SIZE=$(du -sh "$DEST" | cut -f1)

echo -e "${GREEN}✓ Copied $FILE_COUNT files ($SIZE)${NC}"

# Initialize Git repository
cd "$DEST"

if [[ -d ".git" ]]; then
  echo -e "${YELLOW}Warning: .git directory found (this shouldn't happen)${NC}"
  rm -rf .git
fi

git init -q
echo -e "${GREEN}✓ Initialized Git repository${NC}"

# Create initial commit
git add .
git commit -q -m "feat: migrated from monorepo"
echo -e "${GREEN}✓ Initial commit created${NC}"

echo ""
echo -e "${GREEN}✅ Successfully copied $PROJECT_NAME to $DEST${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo "  cd $DEST"
echo "  git remote add origin <your-repo-url>"
echo "  git push -u origin main"
