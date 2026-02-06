Write-Host "Checking Node.js and npm installation..." -ForegroundColor Cyan
Write-Host ""

# Check for Node.js
Write-Host "Looking for Node.js:" -ForegroundColor Green
try {
    $nodePath = (Get-Command node -ErrorAction Stop).Path
    Write-Host "Node.js is installed at: $nodePath" -ForegroundColor Green
    
    # Check Node.js version
    Write-Host "`nNode.js version:" -ForegroundColor Green
    $nodeVersion = node --version
    Write-Host $nodeVersion -ForegroundColor Green
} catch {
    Write-Host "Node.js is NOT installed or not in PATH" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
}

# Check for npm
Write-Host "`nLooking for npm:" -ForegroundColor Green
try {
    $npmPath = (Get-Command npm -ErrorAction Stop).Path
    Write-Host "npm is installed at: $npmPath" -ForegroundColor Green
    
    # Check npm version
    Write-Host "`nnpm version:" -ForegroundColor Green
    $npmVersion = npm --version
    Write-Host $npmVersion -ForegroundColor Green
} catch {
    Write-Host "npm is NOT installed or not in PATH" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
}

# Check standard installation locations
Write-Host "`nChecking standard installation locations:" -ForegroundColor Green
$standardPaths = @(
    "$env:ProgramFiles\nodejs\node.exe",
    "${env:ProgramFiles(x86)}\nodejs\node.exe"
)

foreach ($path in $standardPaths) {
    if (Test-Path $path) {
        Write-Host "Found Node.js at: $path" -ForegroundColor Green
    }
}

Write-Host "`nIf Node.js was not found, please install it from: https://nodejs.org/" -ForegroundColor Yellow
Write-Host "After installation, you may need to restart your computer." -ForegroundColor Yellow

Write-Host "`nPress Enter to exit..." -ForegroundColor Cyan
Read-Host 