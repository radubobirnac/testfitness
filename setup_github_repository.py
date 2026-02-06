#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys

def update_mcp_settings(token):
    """Update the MCP settings file with the GitHub token."""
    # Path to the MCP settings file
    settings_path = os.path.expanduser("c:/Users/radub/AppData/Roaming/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json")
    
    # Read the current settings
    with open(settings_path, 'r') as f:
        settings = json.load(f)
    
    # Update the GitHub server configuration
    if 'github' in settings['mcpServers']:
        settings['mcpServers']['github']['args'] = [
            "C:\\Users\\radub\\OneDrive\\Documents\\Cline\\MCP\\github-server\\github_server.py",
            "--token",
            token
        ]
    else:
        settings['mcpServers']['github'] = {
            "command": "python",
            "args": [
                "C:\\Users\\radub\\OneDrive\\Documents\\Cline\\MCP\\github-server\\github_server.py",
                "--token",
                token
            ],
            "disabled": False,
            "autoApprove": []
        }
    
    # Write the updated settings
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
    
    print(f"Updated MCP settings with GitHub token")

def setup_repository(project_name, description):
    """Set up a GitHub repository for the project using the GitHub MCP server."""
    print(f"Setting up GitHub repository: {project_name}")
    print(f"Description: {description}")
    print("\nIMPORTANT: This script doesn't actually create the repository.")
    print("Once you've added your GitHub token to the MCP settings,")
    print("you can use the following commands with Claude to create and manage repositories:")
    print("\n1. Use the 'github' MCP server in Cline like this:")
    print("```")
    print("<use_mcp_tool>")
    print("<server_name>github</server_name>")
    print("<tool_name>create_repository</tool_name>")
    print("<arguments>")
    print("{")
    print(f'  "name": "{project_name}",')
    print(f'  "description": "{description}",')
    print('  "private": false,')
    print('  "auto_init": true')
    print("}")
    print("</arguments>")
    print("</use_mcp_tool>")
    print("```")
    print("\n2. After the repository is created, check your repositories:")
    print("```")
    print("<use_mcp_tool>")
    print("<server_name>github</server_name>")
    print("<tool_name>get_repositories</tool_name>")
    print("<arguments>{}</arguments>")
    print("</use_mcp_tool>")
    print("```")
    print("\n3. Build and deploy your web application with GitHub Pages:")
    print("```")
    print("<use_mcp_tool>")
    print("<server_name>flutter-web</server_name>")
    print("<tool_name>prepare_github_pages</tool_name>")
    print("<arguments>")
    print("{")
    print('  "project_path": "c:/Users/radub/testfitness",')
    print('  "base_href": "/test-fitness/"')
    print("}")
    print("</arguments>")
    print("</use_mcp_tool>")
    print("```")
    print("\n4. Enable GitHub Pages for your repository:")
    print("```")
    print("<use_mcp_tool>")
    print("<server_name>github</server_name>")
    print("<tool_name>enable_github_pages</tool_name>")
    print("<arguments>")
    print("{")
    print('  "owner": "YOUR_GITHUB_USERNAME",')
    print(f'  "repo": "{project_name}",')
    print('  "source_branch": "main"')
    print("}")
    print("</arguments>")
    print("</use_mcp_tool>")
    print("```")

def main():
    parser = argparse.ArgumentParser(description="Setup GitHub repository for Flutter fitness app")
    parser.add_argument("--token", help="GitHub API token")
    parser.add_argument("--project", default="test-fitness", help="Repository name")
    parser.add_argument("--description", default="Flutter strength training application", help="Repository description")
    args = parser.parse_args()
    
    # If token is provided, update the MCP settings
    if args.token:
        update_mcp_settings(args.token)
    else:
        print("No token provided. Please follow the GitHub_PAT_Guide.md to create a token.")
        print("Then run this script again with: python setup_github_repository.py --token YOUR_TOKEN")
    
    # Show how to set up the repository
    setup_repository(args.project, args.description)

if __name__ == "__main__":
    main()
