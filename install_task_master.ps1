Write-Host "Installing Task Master AI..." -ForegroundColor Cyan
Write-Host "This script will install task-master-ai globally and initialize it in your project." -ForegroundColor Cyan
Write-Host ""

# Install Task Master AI
Write-Host "Step 1: Installing task-master-ai globally..." -ForegroundColor Green
try {
    # Try to install globally
    npm install -g task-master-ai
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install task-master-ai globally"
    }
    
    Write-Host "Task Master AI installed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error installing Task Master AI globally: $_" -ForegroundColor Red
    Write-Host "Attempting alternative installation methods..." -ForegroundColor Yellow
    
    try {
        # Try with force flag
        Write-Host "Trying with --force flag..." -ForegroundColor Yellow
        npm install -g task-master-ai --force
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install with --force flag"
        }
        
        Write-Host "Task Master AI installed successfully with --force!" -ForegroundColor Green
    } catch {
        Write-Host "Error with force installation: $_" -ForegroundColor Red
        
        # Try local installation
        try {
            Write-Host "Trying local installation..." -ForegroundColor Yellow
            npm install task-master-ai
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to install locally"
            }
            
            Write-Host "Task Master AI installed locally!" -ForegroundColor Green
            $localInstall = $true
        } catch {
            Write-Host "All installation methods failed: $_" -ForegroundColor Red
            Write-Host "Please check npm permissions or try running PowerShell as Administrator." -ForegroundColor Red
            $installFailed = $true
        }
    }
}

# Initialize Task Master if installation was successful
if (-not $installFailed) {
    Write-Host "`nStep 2: Initializing Task Master in your project..." -ForegroundColor Green
    
    try {
        if ($localInstall) {
            # Use npx for local installation
            Write-Host "Using npx to run local installation..." -ForegroundColor Yellow
            npx task-master init
        } else {
            # Try direct command first
            Write-Host "Running task-master init..." -ForegroundColor Green
            task-master init
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to initialize Task Master"
        }
        
        Write-Host "Task Master initialized successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Error initializing Task Master: $_" -ForegroundColor Red
        Write-Host "Trying alternative initialization method..." -ForegroundColor Yellow
        
        try {
            # Try with npx as fallback
            Write-Host "Trying with npx..." -ForegroundColor Yellow
            npx task-master init
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to initialize with npx"
            }
            
            Write-Host "Task Master initialized successfully with npx!" -ForegroundColor Green
        } catch {
            Write-Host "All initialization methods failed: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nAll operations completed. Check messages above for any errors." -ForegroundColor Cyan
if (-not $installFailed) {
    Write-Host "If Task Master initialized successfully, you should see new files including a .env.example file." -ForegroundColor Cyan
    Write-Host "Remember to create a .env file with your API keys as described in the setup guide." -ForegroundColor Cyan
}

Write-Host "`nPress Enter to exit..." -ForegroundColor Cyan
Read-Host 