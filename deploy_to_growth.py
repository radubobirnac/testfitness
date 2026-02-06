#!/usr/bin/env python3
import os
import subprocess
import tempfile
import shutil
import requests
import sys

# Your token - updated with new token that has more permissions
TOKEN = "YOUR_GITHUB_TOKEN"
USERNAME = "radubobirnac"
REPO_NAME = "Growth"
BRANCH = "gh-pages"
WEB_BUILD_DIR = "build/web"

def get_user_info():
    """Get GitHub user info to verify token works"""
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {TOKEN}",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    
    response = requests.get("https://api.github.com/user", headers=headers)
    
    if response.status_code == 200:
        user_data = response.json()
        print(f"User information:")
        print(f"  Login: {user_data['login']}")
        print(f"  Name: {user_data.get('name', 'N/A')}")
        print(f"  URL: {user_data['html_url']}")
        return user_data
    else:
        print(f"Error fetching user information: {response.status_code}")
        try:
            error_data = response.json()
            print(f"Error message: {error_data.get('message', 'Unknown error')}")
        except:
            print(f"Response: {response.text}")
        return None

def deploy_to_github_pages():
    """Deploy Flutter web build to GitHub Pages using direct git commands"""
    print(f"Deploying to GitHub Pages...")
    
    # Check if web build directory exists
    if not os.path.exists(WEB_BUILD_DIR):
        print(f"Error: Web build directory '{WEB_BUILD_DIR}' not found.")
        print(f"Current working directory: {os.getcwd()}")
        print(f"Directory contents: {os.listdir('.')}")
        if os.path.exists('build'):
            print(f"Build directory contents: {os.listdir('build')}")
        sys.exit(1)
    
    # Verify user info
    user_info = get_user_info()
    if not user_info:
        print("Error: Could not get user information from GitHub API.")
        sys.exit(1)
    
    # Check if git is installed
    try:
        subprocess.run(["git", "--version"], check=True, capture_output=True, text=True)
    except:
        print("Error: Git is not installed or not available in PATH.")
        sys.exit(1)
    
    # Create a temporary directory for the deployment
    temp_dir = tempfile.mkdtemp()
    print(f"Created temporary directory for deployment: {temp_dir}")
    
    try:
        # Initialize git repo
        print("Initializing git repository...")
        subprocess.run(["git", "init"], cwd=temp_dir, check=True, capture_output=True, text=True)
        
        # Configure git user
        print("Configuring git user...")
        subprocess.run(["git", "config", "user.name", user_info.get("login", "GitHub User")], 
                      cwd=temp_dir, check=True, capture_output=True, text=True)
        subprocess.run(["git", "config", "user.email", "noreply@github.com"], 
                      cwd=temp_dir, check=True, capture_output=True, text=True)
        
        # Copy web build files to temp directory
        print(f"Copying web build files from '{WEB_BUILD_DIR}' to temp directory...")
        print(f"Web build directory contents: {os.listdir(WEB_BUILD_DIR)}")
        
        for item in os.listdir(WEB_BUILD_DIR):
            src = os.path.join(WEB_BUILD_DIR, item)
            dst = os.path.join(temp_dir, item)
            if os.path.isdir(src):
                print(f"Copying directory: {item}")
                shutil.copytree(src, dst)
            else:
                print(f"Copying file: {item}")
                shutil.copy2(src, dst)
        
        # Add files to git
        print("Adding files to git...")
        subprocess.run(["git", "add", "."], cwd=temp_dir, check=True, capture_output=True, text=True)
        
        # Commit
        print("Committing changes...")
        result = subprocess.run(["git", "commit", "-m", "Deploy to GitHub Pages"], 
                      cwd=temp_dir, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"Warning: Git commit returned non-zero exit code: {result.returncode}")
            print(f"Stdout: {result.stdout}")
            print(f"Stderr: {result.stderr}")
            if "nothing to commit" in result.stderr:
                print("No changes to commit. Continuing anyway...")
            else:
                raise subprocess.CalledProcessError(result.returncode, result.args, result.stdout, result.stderr)
        
        # Add remote
        print("Adding remote...")
        # Using HTTPS with token in URL for authentication
        remote_url = f"https://{USERNAME}:{TOKEN}@github.com/{USERNAME}/{REPO_NAME}.git"
        subprocess.run(["git", "remote", "add", "origin", remote_url], 
                      cwd=temp_dir, check=True, capture_output=True, text=True)
        
        # Push to GitHub - forcing to overwrite existing history on the branch
        print(f"Pushing to GitHub (branch: {BRANCH})...")
        push_result = subprocess.run(["git", "push", "-f", "origin", f"HEAD:{BRANCH}"], 
                      cwd=temp_dir, capture_output=True, text=True)
        
        if push_result.returncode != 0:
            print(f"Error pushing to GitHub:")
            print(f"Return code: {push_result.returncode}")
            print(f"Stdout: {push_result.stdout}")
            print(f"Stderr: {push_result.stderr}")
            sys.exit(1)
        else:
            print(f"Successfully pushed to GitHub!")
        
        print(f"Successfully deployed to GitHub Pages branch: {BRANCH}")
        print(f"Your site will be available at: https://{USERNAME}.github.io/{REPO_NAME}/")
        
        # Enable GitHub Pages functionality via API
        enable_github_pages()
        
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error deploying to GitHub Pages:")
        print(f"Command: {e.cmd}")
        print(f"Return code: {e.returncode}")
        print(f"Stdout: {e.stdout}")
        print(f"Stderr: {e.stderr}")
        return False
    except Exception as e:
        print(f"Error deploying to GitHub Pages: {str(e)}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        # Clean up temporary directory
        try:
            shutil.rmtree(temp_dir)
            print(f"Cleaned up temporary directory.")
        except Exception as e:
            print(f"Warning: Could not clean up temporary directory: {str(e)}")

def enable_github_pages():
    """Try to enable GitHub Pages via API if permissions allow"""
    url = f"https://api.github.com/repos/{USERNAME}/{REPO_NAME}/pages"
    
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {TOKEN}",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    
    data = {
        "source": {
            "branch": BRANCH,
            "path": "/"
        }
    }
    
    print(f"Enabling GitHub Pages for {USERNAME}/{REPO_NAME} (branch: {BRANCH})...")
    response = requests.post(url, headers=headers, json=data)
    
    if response.status_code in [201, 204]:
        print(f"GitHub Pages enabled successfully!")
        print(f"Repository: {USERNAME}/{REPO_NAME}")
        print(f"Source Branch: {BRANCH}")
        
        # Try to get the Pages URL
        get_response = requests.get(url, headers=headers)
        
        if get_response.status_code == 200:
            pages_data = get_response.json()
            pages_url = pages_data.get("html_url", "Unknown")
            print(f"Pages URL: {pages_url}")
        else:
            print(f"Pages URL: https://{USERNAME}.github.io/{REPO_NAME}/")
            
        print(f"Note: It may take a few minutes for your site to be available.")
    else:
        print(f"Note: Could not automatically enable GitHub Pages (status {response.status_code}).")
        try:
            error_data = response.json()
            print(f"Error message: {error_data.get('message', 'Unknown error')}")
        except:
            print(f"Response: {response.text}")
        print(f"You may need to enable it manually in the repository settings:")
        print(f"1. Go to https://github.com/{USERNAME}/{REPO_NAME}/settings/pages")
        print(f"2. Select branch '{BRANCH}' as the source")
        print(f"3. Click Save")
        print(f"Your site will then be available at: https://{USERNAME}.github.io/{REPO_NAME}/")

if __name__ == "__main__":
    deploy_to_github_pages()
