# Update GitHub Token Permissions

Your current GitHub token (`YOUR_GITHUB_TOKEN`) has limited permissions and cannot create repositories. This is common with fine-grained tokens that have specific scopes.

## Steps to Create a New Token with Required Permissions:

1. Go to [GitHub Personal Access Tokens](https://github.com/settings/tokens)
2. Either:
   - Click "Regenerate" on your existing token
   - Or create a new token by clicking "Generate new token" under "Classic tokens"

3. **For a classic token**:
   - Name: "Cline Flutter GitHub Integration"
   - Expiration: Select an appropriate duration
   - Scopes: Select the following permissions:
     - `repo` (Full control of private repositories)
     - `workflow` (if you plan to use GitHub Actions)
     - `read:org` (if working with organization repositories)

4. **For a fine-grained token**:
   - Name: "Cline Flutter GitHub Integration"
   - Expiration: Select an appropriate duration
   - Repository access: "All repositories" or select specific repositories
   - Permissions:
     - Repository permissions:
       - Administration: "Read and write" (for GitHub Pages)
       - Contents: "Read and write" (for pushing code)
       - Pages: "Read and write" (for enabling GitHub Pages)
       - Issues: "Read and write" (optional)

5. Click "Generate token"
6. Copy the new token and use it in the script

## After Getting the New Token:

Replace the token in the commands:

```bash
python github_api.py --token YOUR_NEW_TOKEN --action setup --project-path . --repo-name testfitness --description "Flutter strength training application"
```

## Alternative: Use Existing Repository

If you prefer not to create a new token, we can deploy to your existing "Growth" repository:

```bash
python github_api.py --token YOUR_GITHUB_TOKEN --action build --project-path . --base-href "/Growth/"
python github_api.py --token YOUR_GITHUB_TOKEN --action deploy --project-path . --repo-name Growth
