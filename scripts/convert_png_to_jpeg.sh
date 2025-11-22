#!/bin/bash

# PNG to JPEG Converter Script
# Converts all PNG files in a directory to JPEG with 85% quality
# Usage: ./convert_png_to_jpeg.sh <source_directory> [output_directory]

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if source directory is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Source directory not provided${NC}"
    echo "Usage: $0 <source_directory> [output_directory]"
    echo "Example: $0 ~/Downloads/thumbnails ~/Downloads/thumbnails_jpeg"
    exit 1
fi

SOURCE_DIR="$1"
OUTPUT_DIR="${2:-${SOURCE_DIR}_jpeg}"

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Error: Source directory '$SOURCE_DIR' does not exist${NC}"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Count PNG files
PNG_COUNT=$(find "$SOURCE_DIR" -maxdepth 1 -type f -name "*.png" | wc -l | tr -d ' ')

if [ "$PNG_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No PNG files found in '$SOURCE_DIR'${NC}"
    exit 0
fi

echo -e "${GREEN}Found $PNG_COUNT PNG file(s)${NC}"
echo -e "${GREEN}Converting to JPEG (85% quality)...${NC}"
echo ""

# Convert each PNG to JPEG
CONVERTED=0
FAILED=0
TOTAL_SIZE_PNG=0
TOTAL_SIZE_JPEG=0

for png_file in "$SOURCE_DIR"/*.png; do
    if [ -f "$png_file" ]; then
        filename=$(basename "$png_file" .png)
        output_file="$OUTPUT_DIR/${filename}.jpg"
        
        # Get file sizes
        png_size=$(stat -f%z "$png_file" 2>/dev/null || stat -c%s "$png_file" 2>/dev/null)
        TOTAL_SIZE_PNG=$((TOTAL_SIZE_PNG + png_size))
        
        # Convert using sips (macOS built-in)
        if sips -s format jpeg -s formatOptions 85 "$png_file" --out "$output_file" > /dev/null 2>&1; then
            jpeg_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
            TOTAL_SIZE_JPEG=$((TOTAL_SIZE_JPEG + jpeg_size))
            
            # Calculate reduction
            reduction=$(echo "scale=1; (1 - $jpeg_size / $png_size) * 100" | bc)
            
            echo -e "${GREEN}✓${NC} $(basename "$png_file") → $(basename "$output_file") (${reduction}% smaller)"
            CONVERTED=$((CONVERTED + 1))
        else
            echo -e "${RED}✗${NC} Failed to convert $(basename "$png_file")"
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Conversion Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Converted: $CONVERTED"
if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
fi
echo ""

# Calculate total size reduction
if [ "$TOTAL_SIZE_PNG" -gt 0 ]; then
    TOTAL_REDUCTION=$(echo "scale=1; (1 - $TOTAL_SIZE_JPEG / $TOTAL_SIZE_PNG) * 100" | bc)
    
    # Format file sizes
    PNG_MB=$(echo "scale=2; $TOTAL_SIZE_PNG / 1024 / 1024" | bc)
    JPEG_MB=$(echo "scale=2; $TOTAL_SIZE_JPEG / 1024 / 1024" | bc)
    
    echo "Total PNG size: ${PNG_MB} MB"
    echo "Total JPEG size: ${JPEG_MB} MB"
    echo -e "${GREEN}Total reduction: ${TOTAL_REDUCTION}%${NC}"
    echo ""
    echo -e "${GREEN}Output directory: $OUTPUT_DIR${NC}"
fi



