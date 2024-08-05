#!/usr/bin/env bash

if [ -d lambda/build ]; then
  rm -rf lambda/build
fi

# Recreate build directory
mkdir -p lambda/build/function/ lambda/build/layer/

# Copy source files
echo "Copy source files"
cp -r lambda/src lambda/build/function/

# Pack python libraries
echo "Pack python libraries"
pip install -r lambda/requirements.txt -t lambda/build/layer/python

# Remove pycache in build directory
find lambda/build -type f | grep -E "(__pycache__|\.pyc|\.pyo$)" | xargs rm