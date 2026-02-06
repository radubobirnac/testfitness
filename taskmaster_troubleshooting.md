# Taskmaster AI Installation Troubleshooting

If you're having trouble installing or running Taskmaster AI, follow these troubleshooting steps:

## Step 1: Verify Node.js and npm Installation

1. Run the `check_node.bat` file I've created
2. Check the output to confirm:
   - Node.js is installed (should be v14.x or higher)
   - npm is installed (should be v6.x or higher)
   - Both are in your PATH

If Node.js or npm are not found:
- Download and install Node.js from [nodejs.org](https://nodejs.org/)
- Choose the LTS (Long Term Support) version
- The installer will also install npm

## Step 2: Install Taskmaster AI Manually

If the batch file approach doesn't work, try installing manually:

1. Open Command Prompt as Administrator
2. Navigate to your project directory:
   ```
   cd C:\Users\radub\testfitness
   ```
3. Run the installation command:
   ```
   npm install -g Taskmaster-AI
   ```
4. If you get permission errors, try:
   ```
   npm install -g Taskmaster-AI --force
   ```
   
## Step 3: Initialize Taskmaster

After successful installation:

1. In Command Prompt, still in your project directory, run:
   ```
   npx Taskmaster init
   ```
   
   Note: Using `npx` ensures it finds the package even if it's not in PATH

2. Follow the prompts to set up your project
   - Project name (e.g., "TestFitness")
   - Description (can be skipped by pressing Enter)
   - Other optional fields

## Step 4: Check Configuration Files

After initialization:

1. You should see new files and folders:
   - `.env.example` file
   - `scripts` folder
   - New `.cursor` rules

2. Create a `.env` file from `.env.example` and add your API keys

## Alternative: Manual Configuration

If Taskmaster won't install or initialize, you can manually set up a basic version:

1. Create a `scripts` folder
2. Add a `PRD.md` file with your project requirements
3. Update your existing `.cursor` file to include Taskmaster-like rules

## Getting Support

If you continue to face issues:
1. Check the [Taskmaster AI GitHub repository](https://github.com/your-username/Taskmaster-AI) for known issues
2. Consider using the basic task.md approach we've already set up as an alternative 