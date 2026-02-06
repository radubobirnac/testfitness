# Git Tools

A Python-based Git utility that provides similar functionality to the Git MCP server.

## Overview

This tool provides a simple command-line interface for common Git operations, making it easy to interact with Git repositories programmatically or from the command line.

## Features

- Show repository status (`status`)
- View unstaged changes (`diff-unstaged`)
- View staged changes (`diff-staged`)
- Compare branches or commits (`diff`)
- Commit changes (`commit`)
- Add files to staging area (`add`)
- Reset staged changes (`reset`)
- View commit history (`log`)
- Create branches (`create-branch`)
- Switch branches (`checkout`)
- View commit details (`show`)
- Initialize a repository (`init`)

## Usage

```bash
python git_tools.py <command> [options]
```

### Commands

- `status`: Show the working tree status
- `diff-unstaged`: Show changes in working directory not yet staged
- `diff-staged`: Show changes that are staged for commit
- `diff`: Show differences between branches or commits (requires `--target`)
- `commit`: Record changes to the repository (requires `--message`)
- `add`: Add file contents to the staging area (requires `--files`)
- `reset`: Unstage all staged changes
- `log`: Show the commit logs (optional `--max-count`)
- `create-branch`: Create a new branch (requires `--branch`, optional `--start-point`)
- `checkout`: Switch branches (requires `--branch`)
- `show`: Show the contents of a commit (requires `--revision`)
- `init`: Initialize a Git repository

### Options

- `--repo`: Path to Git repository (defaults to current directory)
- `--target`: Target for diff command
- `--message`: Commit message
- `--files`: Files for add command (can specify multiple)
- `--branch`: Branch name
- `--start-point`: Starting point for new branch
- `--revision`: Revision for show command
- `--max-count`: Maximum number of commits to show (default: 10)

## Examples

```bash
# Show repository status
python git_tools.py status

# View unstaged changes
python git_tools.py diff-unstaged

# Add files to staging area
python git_tools.py add --files file1.txt file2.txt

# Commit changes
python git_tools.py commit --message "Add new features"

# View commit history (last 5 commits)
python git_tools.py log --max-count 5

# Create a new branch
python git_tools.py create-branch --branch feature-branch

# Switch to a branch
python git_tools.py checkout --branch main
```

## Requirements

- Python 3.6+
- GitPython library

## Installation

1. Ensure you have Python installed
2. Install the GitPython library:
   ```bash
   pip install gitpython
   ```
3. Download the `git_tools.py` script
4. Make it executable (optional):
   ```bash
   chmod +x git_tools.py
   ```

## Why Use This Instead of MCP Server?

This script provides a simpler alternative to the Git MCP server when:

1. You're having issues with MCP server configuration
2. You need a lightweight solution without additional dependencies
3. You want to integrate Git functionality directly into your Python scripts
4. You prefer a direct command-line interface over MCP's API-based approach
