#!/usr/bin/env python3
import os
import sys
import git
from datetime import datetime

class GitTools:
    """A class that provides Git functionality similar to the MCP server"""
    
    def __init__(self, repo_path=None):
        """Initialize with an optional repository path"""
        self.repo_path = repo_path or os.getcwd()
        try:
            self.repo = git.Repo(self.repo_path)
        except git.exc.InvalidGitRepositoryError:
            print(f"Error: {self.repo_path} is not a valid Git repository")
            self.repo = None
    
    def git_status(self):
        """Show the working tree status"""
        if not self.repo:
            return "Not a valid Git repository"
        
        result = []
        result.append(f"On branch {self.repo.active_branch.name}")
        
        # Check if repo is dirty
        if self.repo.is_dirty():
            result.append("Changes not staged for commit:")
            for item in self.repo.index.diff(None):
                result.append(f"  modified: {item.a_path}")
        
        # Check for untracked files
        untracked = self.repo.untracked_files
        if untracked:
            result.append("Untracked files:")
            for file in untracked:
                result.append(f"  {file}")
        
        # Check for staged changes
        staged = self.repo.index.diff("HEAD")
        if staged:
            result.append("Changes to be committed:")
            for item in staged:
                result.append(f"  modified: {item.a_path}")
        
        if not self.repo.is_dirty() and not untracked and not staged:
            result.append("Working tree clean")
        
        return "\n".join(result)
    
    def git_diff_unstaged(self):
        """Show changes in working directory not yet staged"""
        if not self.repo:
            return "Not a valid Git repository"
        
        result = []
        for diff_item in self.repo.index.diff(None):
            result.append(f"diff --git a/{diff_item.a_path} b/{diff_item.b_path}")
            result.append(f"--- a/{diff_item.a_path}")
            result.append(f"+++ b/{diff_item.b_path}")
            diff_text = diff_item.diff
            if isinstance(diff_text, bytes):
                diff_text = diff_text.decode('utf-8')
            result.append(diff_text)
        
        return "\n".join(result) if result else "No unstaged changes"
    
    def git_diff_staged(self):
        """Show changes that are staged for commit"""
        if not self.repo:
            return "Not a valid Git repository"
        
        result = []
        for diff_item in self.repo.index.diff("HEAD"):
            result.append(f"diff --git a/{diff_item.a_path} b/{diff_item.b_path}")
            result.append(f"--- a/{diff_item.a_path}")
            result.append(f"+++ b/{diff_item.b_path}")
            diff_text = diff_item.diff
            if isinstance(diff_text, bytes):
                diff_text = diff_text.decode('utf-8')
            result.append(diff_text)
        
        return "\n".join(result) if result else "No staged changes"
    
    def git_diff(self, target):
        """Show differences between branches or commits"""
        if not self.repo:
            return "Not a valid Git repository"
        
        try:
            diff = self.repo.git.diff(target)
            return diff if diff else f"No differences between current state and {target}"
        except git.exc.GitCommandError as e:
            return f"Error: {str(e)}"
    
    def git_commit(self, message):
        """Record changes to the repository"""
        if not self.repo:
            return "Not a valid Git repository"
        
        try:
            self.repo.git.commit('-m', message)
            return f"Committed changes with message: {message}"
        except git.exc.GitCommandError as e:
            return f"Error: {str(e)}"
    
    def git_add(self, files):
        """Add file contents to the staging area"""
        if not self.repo:
            return "Not a valid Git repository"
        
        try:
            if isinstance(files, list):
                for file in files:
                    self.repo.git.add(file)
                return f"Added files to staging area: {', '.join(files)}"
            else:
                self.repo.git.add(files)
                return f"Added {files} to staging area"
        except git.exc.GitCommandError as e:
            return f"Error: {str(e)}"
    
    def git_reset(self):
        """Unstage all staged changes"""
        if not self.repo:
            return "Not a valid Git repository"
        
        try:
            self.repo.git.reset()
            return "Reset all staged changes"
        except git.exc.GitCommandError as e:
            return f"Error: {str(e)}"
    
    def git_log(self, max_count=10):
        """Show the commit logs"""
        if not self.repo:
            return "Not a valid Git repository"
        
        result = []
        for commit in list(self.repo.iter_commits())[:max_count]:
            commit_time = datetime.fromtimestamp(commit.committed_date)
            result.append(f"commit {commit.hexsha}")
            result.append(f"Author: {commit.author.name} <{commit.author.email}>")
            result.append(f"Date:   {commit_time.strftime('%a %b %d %H:%M:%S %Y')}")
            result.append("")
            result.append(f"    {commit.message}")
            result.append("")
        
        return "\n".join(result) if result else "No commits found"
    
    def git_create_branch(self, branch_name, start_point=None):
        """Create a new branch"""
        if not self.repo:
            return "Not a valid Git repository"
        
        try:
            if start_point:
                self.repo.git.branch(branch_name, start_point)
            else:
                self.repo.git.branch(branch_name)
            return f"Created branch: {branch_name}"
        except git.exc.GitCommandError as e:
            return f"Error: {str(e)}"
    
    def git_checkout(self, branch_name):
        """Switch branches"""
        if not self.repo:
            return "Not a valid Git repository"
        
        try:
            self.repo.git.checkout(branch_name)
            return f"Switched to branch: {branch_name}"
        except git.exc.GitCommandError as e:
            return f"Error: {str(e)}"
    
    def git_show(self, revision):
        """Show the contents of a commit"""
        if not self.repo:
            return "Not a valid Git repository"
        
        try:
            return self.repo.git.show(revision)
        except git.exc.GitCommandError as e:
            return f"Error: {str(e)}"
    
    def git_init(self):
        """Initialize a Git repository"""
        try:
            git.Repo.init(self.repo_path)
            return f"Initialized empty Git repository in {self.repo_path}"
        except Exception as e:
            return f"Error: {str(e)}"


if __name__ == "__main__":
    # Simple CLI interface
    import argparse
    
    parser = argparse.ArgumentParser(description="Git Tools")
    parser.add_argument("--repo", help="Path to Git repository")
    parser.add_argument("command", choices=[
        "status", "diff-unstaged", "diff-staged", "diff", "commit", 
        "add", "reset", "log", "create-branch", "checkout", "show", "init"
    ], help="Git command to execute")
    parser.add_argument("--target", help="Target for diff command")
    parser.add_argument("--message", help="Commit message")
    parser.add_argument("--files", nargs="+", help="Files for add command")
    parser.add_argument("--branch", help="Branch name")
    parser.add_argument("--start-point", help="Starting point for new branch")
    parser.add_argument("--revision", help="Revision for show command")
    parser.add_argument("--max-count", type=int, default=10, help="Maximum number of commits to show")
    
    args = parser.parse_args()
    
    git_tools = GitTools(args.repo)
    
    if args.command == "status":
        print(git_tools.git_status())
    elif args.command == "diff-unstaged":
        print(git_tools.git_diff_unstaged())
    elif args.command == "diff-staged":
        print(git_tools.git_diff_staged())
    elif args.command == "diff":
        if not args.target:
            print("Error: --target is required for diff command")
            sys.exit(1)
        print(git_tools.git_diff(args.target))
    elif args.command == "commit":
        if not args.message:
            print("Error: --message is required for commit command")
            sys.exit(1)
        print(git_tools.git_commit(args.message))
    elif args.command == "add":
        if not args.files:
            print("Error: --files is required for add command")
            sys.exit(1)
        print(git_tools.git_add(args.files))
    elif args.command == "reset":
        print(git_tools.git_reset())
    elif args.command == "log":
        print(git_tools.git_log(args.max_count))
    elif args.command == "create-branch":
        if not args.branch:
            print("Error: --branch is required for create-branch command")
            sys.exit(1)
        print(git_tools.git_create_branch(args.branch, args.start_point))
    elif args.command == "checkout":
        if not args.branch:
            print("Error: --branch is required for checkout command")
            sys.exit(1)
        print(git_tools.git_checkout(args.branch))
    elif args.command == "show":
        if not args.revision:
            print("Error: --revision is required for show command")
            sys.exit(1)
        print(git_tools.git_show(args.revision))
    elif args.command == "init":
        print(git_tools.git_init())
