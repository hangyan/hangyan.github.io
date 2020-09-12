#!/usr/bin/env bash
!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

# Build the project.
hugo -t even #if using a theme, replace with `hugo -t <YOURTHEME>`

# Go To Public folder
cd public

# Add changes to git.
git add .

git commit -m "Update site"

# Push source and build repos.
git push upstream master

# Come Back up to the Project Root
cd ..
