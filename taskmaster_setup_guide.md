# Taskmaster AI Setup Guide

## Installation

1. Install Taskmaster AI globally:
   ```
   npm install -g Taskmaster-AI
   ```

2. Set up the project:
   ```
   Taskmaster init
   ```
   - This will ask for a project name and description
   - You can skip optional fields if not needed

## Configuration

1. After initialization, locate the `.env.example` file
2. Copy it to `.env` and add your API keys:
   - Add your Anthropic (Claude) API key
   - Add your Perplexity API key (if available)

## Usage Commands

### Breaking Down Tasks
```
Taskmaster parse PRD
```
This will break down your PRD into smaller, manageable tasks in logical order.

### Analyzing Complexity
```
Taskmaster analyze complexities
```
This will analyze how complex each task is and can help identify tasks that need to be broken down further.

### Reviewing Tasks
```
Taskmaster list tasks
```
Shows all tasks, their dependencies, and status.

## Integration with AI Coding Agents

Taskmaster AI creates Cursor rules automatically that teach Cursor how to:
1. Add new Cursor rules
2. Self-improve based on experience
3. Work with the task system to check tasks in the backlog

The `.cursor` file we created will work alongside Taskmaster to help your AI coding agent keep track of task progress.

## Project Setup

For a new project, it's recommended to:
1. Set up your project structure first (e.g., for Next.js: `npx create-next-app my-app`)
2. Then install and initialize Taskmaster inside that project

## Creating a PRD

You can create a PRD (Product Requirements Document) through several methods:
1. Use Cursor to help generate a PRD
2. If you're in the AI Builder Club, use tools like tankscoder.dev
3. Write one manually in the format expected by Taskmaster

Your PRD will be used by Taskmaster to generate the task list for your project. 