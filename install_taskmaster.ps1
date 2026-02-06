Write-Host "Installing Taskmaster AI..." -ForegroundColor Cyan
Write-Host "This script will install Taskmaster AI globally and initialize it in your project." -ForegroundColor Cyan
Write-Host ""

# Install Taskmaster AI
Write-Host "Step 1: Installing Taskmaster AI globally..." -ForegroundColor Green
try {
    # Try to install globally
    npm install -g Taskmaster-AI
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Taskmaster-AI globally"
    }
    
    Write-Host "Taskmaster AI installed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error installing Taskmaster AI globally: $_" -ForegroundColor Red
    Write-Host "Attempting alternative installation methods..." -ForegroundColor Yellow
    
    try {
        # Try with force flag
        Write-Host "Trying with --force flag..." -ForegroundColor Yellow
        npm install -g Taskmaster-AI --force
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install with --force flag"
        }
        
        Write-Host "Taskmaster AI installed successfully with --force!" -ForegroundColor Green
    } catch {
        Write-Host "Error with force installation: $_" -ForegroundColor Red
        
        # Try local installation
        try {
            Write-Host "Trying local installation..." -ForegroundColor Yellow
            npm install Taskmaster-AI
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to install locally"
            }
            
            Write-Host "Taskmaster AI installed locally!" -ForegroundColor Green
            $localInstall = $true
        } catch {
            Write-Host "All installation methods failed: $_" -ForegroundColor Red
            Write-Host "Please check npm permissions or try running PowerShell as Administrator." -ForegroundColor Red
            $installFailed = $true
        }
    }
}

# Initialize Taskmaster if installation was successful
if (-not $installFailed) {
    Write-Host "`nStep 2: Initializing Taskmaster in your project..." -ForegroundColor Green
    
    try {
        if ($localInstall) {
            # Use npx for local installation
            Write-Host "Using npx to run local installation..." -ForegroundColor Yellow
            npx Taskmaster init
        } else {
            # Try direct command first
            Write-Host "Running Taskmaster init..." -ForegroundColor Green
            Taskmaster init
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to initialize Taskmaster"
        }
        
        Write-Host "Taskmaster initialized successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Error initializing Taskmaster: $_" -ForegroundColor Red
        Write-Host "Trying alternative initialization method..." -ForegroundColor Yellow
        
        try {
            # Try with npx as fallback
            Write-Host "Trying with npx..." -ForegroundColor Yellow
            npx Taskmaster init
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to initialize with npx"
            }
            
            Write-Host "Taskmaster initialized successfully with npx!" -ForegroundColor Green
        } catch {
            Write-Host "All initialization methods failed: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nAll operations completed. Check messages above for any errors." -ForegroundColor Cyan
if (-not $installFailed) {
    Write-Host "If Taskmaster initialized successfully, you should see new files including a .env.example file." -ForegroundColor Cyan
    Write-Host "Remember to create a .env file with your API keys as described in the setup guide." -ForegroundColor Cyan
}

Write-Host "`nPress Enter to exit..." -ForegroundColor Cyan
Read-Host 