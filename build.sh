#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
GOOS="linux"
GOARCH="amd64"
OUTPUT="bootstrap"
SOURCE="main.go"

# Check if the directory argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

# Set the directory
DIR="$1"

# Ensure the directory and source file exist
if [ ! -d "$DIR" ]; then
  echo "Error: Directory $DIR does not exist!"
  exit 1
fi

if [ ! -f "$DIR/$SOURCE" ]; then
  echo "Error: $SOURCE not found in $DIR!"
  exit 1
fi

# Compile the Go source file for Linux
echo "Compiling $SOURCE for $GOOS/$GOARCH..."
GOOS=$GOOS GOARCH=$GOARCH go build -o "$DIR/$OUTPUT" "$DIR/$SOURCE"

# Verify if the binary was created successfully
if [ -f "$DIR/$OUTPUT" ]; then
  echo "Compilation successful: $DIR/$OUTPUT created."
else
  echo "Error: Compilation failed!"
  exit 1
fi

echo "Build process completed successfully."
