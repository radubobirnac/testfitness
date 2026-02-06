# Git MCP Server Setup

This document outlines the setup and usage of the Git MCP server for the testfitness project.

## Current Configuration

The Git MCP server is configured in two ways:

1. **Docker Compose Configuration**
   - Server Name: `github.com/modelcontextprotocol/servers/tree/main/src/git`
   - Located at: `C:\Users\radub\OneDrive\Documents\Cline\MCP\git-mcp\`
   - Mounts the testfitness directory as a workspace
   - Started with: `docker-compose -f C:\Users\radub\OneDrive\Documents\Cline\MCP\git-mcp\docker-compose.yml up`

2. **Python Module Configuration**
   - Server Name: `git-mcp`
   - Directly uses the mcp_server_git Python module
   - Points to the testfitness repository

## Usage Examples

### Using Docker Compose (Recommended)

The Docker approach is recommended as it provides a more isolated environment and doesn't require installing the Git MCP server dependencies directly on your system.

Example commands to use the Git MCP server:

```python
# Example code to use git status
response = use_mcp_tool(
    server_name="github.com/modelcontextprotocol/servers/tree/main/src/git",
    tool_name="git_status",
    arguments={
        "repo_path": "/workspace"  # Inside Docker, the path is mounted as /workspace
    }
)

# Example to show diff of unstaged changes
response = use_mcp_tool(
    server_name="github.com/modelcontextprotocol/servers/tree/main/src/git",
    tool_name="git_diff_unstaged",
    arguments={
        "repo_path": "/workspace"
    }
)

# Example to create a commit
response = use_mcp_tool(
    server_name="github.com/modelcontextprotocol/servers/tree/main/src/git",
    tool_name="git_commit",
    arguments={
        "repo_path": "/workspace",
        "message": "Update files with new features"
    }
)
```

### Using Python Module

If you prefer to use the Python module directly:

```python
# Example code to use git status
response = use_mcp_tool(
    server_name="git-mcp",
    tool_name="git_status",
    arguments={
        "repo_path": "c:/Users/radub/testfitness"
    }
)
```

## Available Tools

- `git_status`: Shows the working tree status
- `git_diff_unstaged`: Shows changes in working directory not yet staged
- `git_diff_staged`: Shows changes that are staged for commit
- `git_diff`: Shows differences between branches or commits
- `git_commit`: Records changes to the repository
- `git_add`: Adds file contents to the staging area
- `git_reset`: Unstages all staged changes
- `git_log`: Shows the commit logs
- `git_create_branch`: Creates a new branch
- `git_checkout`: Switches branches
- `git_show`: Shows the contents of a commit
- `git_init`: Initializes a Git repository

## Troubleshooting

If you encounter issues with the Git MCP server:

1. Ensure Docker is running if using the Docker Compose approach
2. Check the Docker logs for any error messages
3. Ensure the repository path is correct
4. Make sure VSCode has been restarted after updating the MCP settings

For Python module issues, check that the mcp_server_git package is installed correctly.
