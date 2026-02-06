# How to Create a GitHub Personal Access Token (PAT)

Follow these steps to create a GitHub Personal Access Token that our GitHub MCP server can use to interact with GitHub on your behalf:

## Step 1: Access GitHub Settings

1. Go to GitHub: https://github.com
2. Sign in with your GitHub account (or create one if you don't have one)
3. Click on your profile picture in the top-right corner
4. Select "Settings" from the dropdown menu

## Step 2: Navigate to Developer Settings

1. Scroll down to the bottom of the left sidebar
2. Click on "Developer settings"

## Step 3: Create a Personal Access Token

1. Click on "Personal access tokens" in the left sidebar
2. Click on "Fine-grained tokens" (for more granular control) or "Tokens (classic)" 
3. Click "Generate new token"

## Step 4: Configure Your Token

1. **Token name**: Give it a descriptive name (e.g., "Cline GitHub Integration")
2. **Expiration**: Select an expiration date (30 days is recommended for security)
3. **Scope selection**: Select the permissions your token needs:
   - For a classic token: At minimum, check "repo" for full control of repositories
   - For a fine-grained token: Configure repository access and permissions as needed

## Step 5: Generate and Copy Your Token

1. Click "Generate token" at the bottom of the page
2. **IMPORTANT**: Copy the generated token immediately and store it securely. GitHub will only show it once!

## Step 6: Configure the GitHub MCP Server

Once you have your token, update the GitHub MCP server configuration in Cline by editing the MCP settings file or setting the GITHUB_TOKEN environment variable:

```json
{
  "mcpServers": {
    "github": {
      "command": "python",
      "args": [
        "C:\\Users\\radub\\OneDrive\\Documents\\Cline\\MCP\\github-server\\github_server.py",
        "--token",
        "your-token-here"
      ],
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

## Security Warning

- Treat your PAT like a password
- Never commit it to version control
- Regenerate it if you suspect it has been compromised
- Use the shortest expiration time reasonable for your needs
