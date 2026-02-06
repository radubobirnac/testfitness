#!/usr/bin/env python3
import argparse
import json
import os
import requests
import sys
import subprocess
from typing import Dict, List, Optional, Any

class GitHubAPI:
    """A class to interact with the GitHub API"""
    
    def __init__(self, token=None):
        self.token = token or os.environ.get("GITHUB_TOKEN")
        if not self.token:
            print("Error: No GitHub token provided. Please provide a token using --token or set the GITHUB_TOKEN environment variable.")
            sys.exit(1)
        
        self.api_url = "https://api.github.com"
        print(f"GitHub API initialized with token: {self.token[:4]}...{self.token[-4:]}")
    
    def get_headers(self):
        """Get HTTP headers for GitHub API requests."""
        return {
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {self.token}",
            "X-GitHub-Api-Version": "2022-11-28",
        }
    
    def get_user_info(self):
        """Get information about the authenticated user."""
        url = f"{self.api_url}/user"
        
        response = requests.get(url, headers=self.get_headers())
        
        if response.status_code == 200:
            user_data = response.json()
            print(f"User information:")
            print(f"  Login: {user_data['login']}")
            print(f"  Name: {user_data.get('name', 'N/A')}")
            print(f"  URL: {user_data['html_url']}")
            print(f"  Public repos: {user_data['public_repos']}")
            print(f"  Followers: {user_data['followers']}")
            print(f"  Following: {user_data['following']}")
            return user_data
        else:
            print(f"Error fetching user information: {response.status_code}")
            try:
                error_data = response.json()
                print(f"Error message: {error_data.get('message', 'Unknown error')}")
            except:
                print(f"Response: {response.text}")
            return None
    
    def list_repositories(self, visibility="all", sort="updated", direction="desc"):
        """List user repositories."""
        url = f"{self.api_url}/user/repos"
        
        params = {
            "visibility": visibility,
            "sort": sort,
            "direction": direction,
        }
        
        response = requests.get(url, headers=self.get_headers(), params=params)
        
        if response.status_code == 200:
            repos = response.json()
            if not repos:
                print("No repositories found.")
                return []
            
            print(f"Found {len(repos)} repositories:")
            for repo in repos:
                print(f"- {repo['name']}: {repo['html_url']}")
                print(f"  Description: {repo['description'] or 'No description'}")
                print(f"  Stars: {repo['stargazers_count']}, Forks: {repo['forks_count']}")
                print(f"  Updated: {repo['updated_at']}")
                print()
            return repos
        else:
            print(f"Error fetching repositories: {response.status_code}")
            try:
                error_data = response.json()
                print(f"Error message: {error_data.get('message', 'Unknown error')}")
            except:
                print(f"Response: {response.text}")
            return []
    
    def create_repository(self, name, description="", private=False, 
                         has_issues=True, has_projects=True, has_wiki=True, 
                         auto_init=False):
        """Create a new GitHub repository."""
        url = f"{self.api_url}/user/repos"
        
        data = {
            "name": name,
            "description": description,
            "private": private,
            "has_issues": has_issues,
            "has_projects": has_projects,
            "has_wiki": has_wiki,
            "auto_init": auto_init,
        }
        
        response = requests.post(url, headers=self.get_headers(), json=data)
        
        if response.status_code == 201:
            repo_data = response.json()
            print(f"Repository created successfully!")
            print(f"Name: {repo_data['name']}")
            print(f"URL: {repo_data['html_url']}")
            print(f"Git URL: {repo_data['clone_url']}")
            print(f"Description: {repo_data['description']}")
            return repo_data
        else:
            print(f"Error creating repository: {response.status_code}")
            try:
                error_data = response.json()
                print(f"Error message: {error_data.get('message', 'Unknown error')}")
            except:
                print(f"Response: {response.text}")
            return None
    
    def create_issue(self, owner, repo, title, body="", labels=None, assignees=None):
        """Create an issue in a repository."""
        url = f"{self.api_url}/repos/{owner}/{repo}/issues"
        
        data = {
            "title": title,
            "body": body,
        }
        
        if labels:
            data["labels"] = labels
        
        if assignees:
            data["assignees"] = assignees
        
        response = requests.post(url, headers=self.get_headers(), json=data)
        
        if response.status_code == 201:
            issue_data = response.json()
            print(f"Issue created successfully!")
            print(f"Title: {issue_data['title']}")
            print(f"URL: {issue_data['html_url']}")
            print(f"Number: {issue_data['number']}")
            return issue_data
        else:
            print(f"Error creating issue: {response.status_code}")
            try:
                error_data = response.json()
                print(f"Error message: {error_data.get('message', 'Unknown error')}")
            except:
                print(f"Response: {response.text}")
            return None
    
    def enable_github_pages(self, owner, repo, source_branch="main"):
        """Enable GitHub Pages for a repository."""
        url = f"{self.api_url}/repos/{owner}/{repo}/pages"
        
        data = {
            "source": {
                "branch": source_branch,
                "path": "/"
            }
        }
        
        response = requests.post(url, headers=self.get_headers(), json=data)
        
        if response.status_code in [201, 204]:
            print(f"GitHub Pages enabled successfully!")
            print(f"Repository: {owner}/{repo}")
            print(f"Source Branch: {source_branch}")
            
            # Try to get the Pages URL
            get_response = requests.get(url, headers=self.get_headers())
            
            if get_response.status_code == 200:
                pages_data = get_response.json()
                pages_url = pages_data.get("html_url", "Unknown")
                print(f"Pages URL: {pages_url}")
                print(f"Note: It may take a few minutes for your site to be available.")
                return pages_data
            else:
                print(f"Pages URL: Will be available at https://{owner}.github.io/{repo}/")
                print(f"Note: It may take a few minutes for your site to be available.")
                return {"html_url": f"https://{owner}.github.io/{repo}/"}
        else:
            print(f"Error enabling GitHub Pages: {response.status_code}")
            try:
                error_data = response.json()
                print(f"Error message: {error_data.get('message', 'Unknown error')}")
            except:
                print(f"Response: {response.text}")
            return None

def build_flutter_web(project_path, base_href=None):
    """Build a Flutter web application."""
    print(f"Building Flutter web application at {project_path}...")
    
    build_cmd = ["flutter", "build", "web", "--release"]
    if base_href:
        build_cmd.extend(["--base-href", base_href])
    
    try:
        result = subprocess.run(
            build_cmd,
            cwd=project_path,
            check=True,
            capture_output=True,
            text=True
        )
        
        print(f"Flutter web build completed successfully.")
        build_dir = os.path.join(project_path, "build", "web")
        print(f"Web files are located at: {build_dir}")
        
        # Create a .nojekyll file to prevent GitHub Pages from processing with Jekyll
        nojekyll_path = os.path.join(build_dir, ".nojekyll")
        if not os.path.exists(nojekyll_path):
            with open(nojekyll_path, "w") as f:
                pass
            print(f"Created .nojekyll file for GitHub Pages.")
        
        return build_dir
    except subprocess.CalledProcessError as e:
        print(f"Error building Flutter web application:")
        print(f"stdout: {e.stdout}")
        print(f"stderr: {e.stderr}")
        return None
    except Exception as e:
        print(f"Error building Flutter web application: {str(e)}")
        return None

def deploy_to_github_pages(github_api, username, repo_name, web_build_dir, branch="gh-pages"):
    """Deploy Flutter web build to GitHub Pages."""
    print(f"Deploying to GitHub Pages...")
    
    # Check if git is installed
    try:
        subprocess.run(["git", "--version"], check=True, capture_output=True)
    except:
        print("Error: Git is not installed or not available in PATH.")
        return False
    
    # Create a temporary directory for the deployment
    import tempfile
    import shutil
    
    temp_dir = tempfile.mkdtemp()
    print(f"Created temporary directory for deployment: {temp_dir}")
    
    try:
        # Initialize git repo
        subprocess.run(["git", "init"], cwd=temp_dir, check=True, capture_output=True)
        
        # Configure git user
        user_info = github_api.get_user_info()
        if user_info:
            subprocess.run(["git", "config", "user.name", user_info.get("login", "GitHub User")], 
                          cwd=temp_dir, check=True, capture_output=True)
            subprocess.run(["git", "config", "user.email", user_info.get("email", "noreply@github.com")], 
                          cwd=temp_dir, check=True, capture_output=True)
        
        # Copy web build files to temp directory
        for item in os.listdir(web_build_dir):
            src = os.path.join(web_build_dir, item)
            dst = os.path.join(temp_dir, item)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)
        
        # Add files to git
        subprocess.run(["git", "add", "."], cwd=temp_dir, check=True, capture_output=True)
        
        # Commit
        subprocess.run(["git", "commit", "-m", "Deploy to GitHub Pages"], 
                      cwd=temp_dir, check=True, capture_output=True)
        
        # Add remote
        remote_url = f"https://{username}:{github_api.token}@github.com/{username}/{repo_name}.git"
        subprocess.run(["git", "remote", "add", "origin", remote_url], 
                      cwd=temp_dir, check=True, capture_output=True)
        
        # Push to GitHub
        subprocess.run(["git", "push", "-f", "origin", f"master:{branch}"], 
                      cwd=temp_dir, check=True, capture_output=True)
        
        print(f"Successfully deployed to GitHub Pages branch: {branch}")
        print(f"Your site will be available at: https://{username}.github.io/{repo_name}/")
        
        # Enable GitHub Pages in the repository settings
        github_api.enable_github_pages(username, repo_name, branch)
        
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error deploying to GitHub Pages:")
        print(f"Command: {e.cmd}")
        print(f"Return code: {e.returncode}")
        print(f"stdout: {e.stdout}")
        print(f"stderr: {e.stderr}")
        return False
    except Exception as e:
        print(f"Error deploying to GitHub Pages: {str(e)}")
        return False
    finally:
        # Clean up temporary directory
        shutil.rmtree(temp_dir)
        print(f"Cleaned up temporary directory.")

def setup_flutter_github_project(token, project_path, repo_name=None, description=None, base_href=None):
    """Set up a GitHub repository for a Flutter project and deploy it to GitHub Pages."""
    github_api = GitHubAPI(token)
    
    # Get user info to determine username
    user_info = github_api.get_user_info()
    if not user_info:
        print("Error: Could not get user information from GitHub API.")
        return
    
    username = user_info["login"]
    print(f"GitHub username: {username}")
    
    if not repo_name:
        repo_name = os.path.basename(os.path.abspath(project_path))
    
    if not description:
        description = f"Flutter web application: {repo_name}"
    
    if not base_href:
        base_href = f"/{repo_name}/"
    
    # Check if repository already exists
    repos = github_api.list_repositories()
    repo_exists = any(repo["name"] == repo_name for repo in repos)
    
    if repo_exists:
        print(f"Repository {repo_name} already exists.")
    else:
        # Create a new repository
        repo_data = github_api.create_repository(
            name=repo_name,
            description=description,
            private=False,
            auto_init=True
        )
        
        if not repo_data:
            print("Error: Failed to create repository.")
            return
    
    # Build the Flutter web application
    web_build_dir = build_flutter_web(project_path, base_href)
    if not web_build_dir:
        print("Error: Failed to build Flutter web application.")
        return
    
    # Deploy to GitHub Pages
    deploy_to_github_pages(github_api, username, repo_name, web_build_dir)

def main():
    parser = argparse.ArgumentParser(description="GitHub API Integration for Flutter Web Apps")
    parser.add_argument("--token", help="GitHub API token")
    parser.add_argument("--action", choices=["setup", "build", "deploy", "create-repo", "list-repos", "enable-pages", "get-user"],
                       default="setup", help="Action to perform")
    parser.add_argument("--project-path", default=".", help="Path to Flutter project")
    parser.add_argument("--repo-name", help="Repository name (defaults to project directory name)")
    parser.add_argument("--description", help="Repository description")
    parser.add_argument("--base-href", help="Base href for Flutter web (defaults to /{repo-name}/)")
    parser.add_argument("--branch", default="gh-pages", help="Branch for GitHub Pages")
    args = parser.parse_args()
    
    token = args.token or os.environ.get("GITHUB_TOKEN")
    if not token:
        print("Error: No GitHub token provided. Please provide a token using --token or set the GITHUB_TOKEN environment variable.")
        sys.exit(1)
    
    github_api = GitHubAPI(token)
    
    if args.action == "get-user":
        github_api.get_user_info()
    
    elif args.action == "list-repos":
        github_api.list_repositories()
    
    elif args.action == "create-repo":
        if not args.repo_name:
            print("Error: Repository name is required for create-repo action.")
            sys.exit(1)
        
        github_api.create_repository(
            name=args.repo_name,
            description=args.description or f"Flutter web application: {args.repo_name}",
            private=False,
            auto_init=True
        )
    
    elif args.action == "build":
        build_flutter_web(args.project_path, args.base_href)
    
    elif args.action == "deploy":
        if not args.repo_name:
            print("Error: Repository name is required for deploy action.")
            sys.exit(1)
        
        user_info = github_api.get_user_info()
        if not user_info:
            print("Error: Could not get user information from GitHub API.")
            sys.exit(1)
        
        username = user_info["login"]
        
        web_build_dir = os.path.join(args.project_path, "build", "web")
        if not os.path.exists(web_build_dir):
            print(f"Error: Flutter web build directory not found at {web_build_dir}.")
            print("Please build the Flutter web app first using: --action=build")
            sys.exit(1)
        
        deploy_to_github_pages(github_api, username, args.repo_name, web_build_dir, args.branch)
    
    elif args.action == "enable-pages":
        if not args.repo_name:
            print("Error: Repository name is required for enable-pages action.")
            sys.exit(1)
        
        user_info = github_api.get_user_info()
        if not user_info:
            print("Error: Could not get user information from GitHub API.")
            sys.exit(1)
        
        username = user_info["login"]
        
        github_api.enable_github_pages(username, args.repo_name, args.branch)
    
    elif args.action == "setup":
        setup_flutter_github_project(
            token,
            args.project_path,
            args.repo_name,
            args.description,
            args.base_href
        )

if __name__ == "__main__":
    main()
