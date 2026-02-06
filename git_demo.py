#!/usr/bin/env python
"""
Git Demo Script - Demonstrates Git operations similar to the Git MCP server
"""

import os
import sys
from git import Repo, GitCommandError

def git_status(repo_path):
    """Shows the working tree status"""
    try:
        repo = Repo(repo_path)
        print(f"Git Status for repository at {repo_path}:")
        
        # Check if the repo is dirty (has changes)
        if repo.is_dirty():
            print("Repository has uncommitted changes")
        else:
            print("Working directory is clean")
        
        # Get status of files
        print("\nUntracked files:")
        for item in repo.untracked_files:
            print(f"  {item}")
        
        # Get staged changes
        print("\nStaged changes:")
        staged_files = [item.a_path for item in repo.index.diff("HEAD")]
        if staged_files:
            for item in staged_files:
                print(f"  {item}")
        else:
            print("  None")
        
        # Get unstaged changes
        print("\nUnstaged changes:")
        unstaged_files = [item.a_path for item in repo.index.diff(None)]
        if unstaged_files:
            for item in unstaged_files:
                print(f"  {item}")
        else:
            print("  None")
            
        return True
    except GitCommandError as e:
        print(f"Git error: {e}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def git_log(repo_path, max_count=10):
    """Shows the commit logs"""
    try:
        repo = Repo(repo_path)
        print(f"Git Log for repository at {repo_path} (last {max_count} commits):")
        
        commits = list(repo.iter_commits('HEAD', max_count=max_count))
        
        for commit in commits:
            print(f"\nCommit: {commit.hexsha}")
            print(f"Author: {commit.author.name} <{commit.author.email}>")
            print(f"Date:   {commit.authored_datetime}")
            print(f"\n    {commit.message}")
            
        return True
    except GitCommandError as e:
        print(f"Git error: {e}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def git_diff_unstaged(repo_path):
    """Shows changes in working directory not yet staged"""
    try:
        repo = Repo(repo_path)
        print(f"Git Diff (unstaged) for repository at {repo_path}:")
        
        diff = repo.git.diff()
        if diff:
            print(diff)
        else:
            print("No unstaged changes")
            
        return True
    except GitCommandError as e:
        print(f"Git error: {e}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def git_diff_staged(repo_path):
    """Shows changes that are staged for commit"""
    try:
        repo = Repo(repo_path)
        print(f"Git Diff (staged) for repository at {repo_path}:")
        
        diff = repo.git.diff('--cached')
        if diff:
            print(diff)
        else:
            print("No staged changes")
            
        return True
    except GitCommandError as e:
        print(f"Git error: {e}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    """Main function to demonstrate Git operations"""
    if len(sys.argv) < 2:
        repo_path = os.getcwd()  # Use current directory if no path provided
    else:
        repo_path = sys.argv[1]
    
    print("Git Demo Script - Demonstrating Git operations\n")
    
    # Demonstrate git_status
    print("\n=== Git Status ===")
    git_status(repo_path)
    
    # Demonstrate git_log
    print("\n=== Git Log ===")
    git_log(repo_path, max_count=5)
    
    # Demonstrate git_diff_unstaged
    print("\n=== Git Diff (Unstaged) ===")
    git_diff_unstaged(repo_path)
    
    # Demonstrate git_diff_staged
    print("\n=== Git Diff (Staged) ===")
    git_diff_staged(repo_path)

if __name__ == "__main__":
    main()
