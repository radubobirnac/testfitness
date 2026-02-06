# Create the .cursor directory and its subdirectories
if (-not (Test-Path -Path ".cursor")) {
    New-Item -Path ".cursor" -ItemType Directory
    Write-Host ".cursor directory created successfully" -ForegroundColor Green
}

if (-not (Test-Path -Path ".cursor\rules")) {
    New-Item -Path ".cursor\rules" -ItemType Directory
    Write-Host ".cursor\rules directory created successfully" -ForegroundColor Green
}

# Now restore our original Task Management System rule
$taskManagementRule = @{
    rules = @(
        @{
            name = "Task Management System"
            description = "Always refer to task.md to track completed and pending tasks, and update it as tasks are completed"
            instructions = "1. Before implementing any new feature, refer to task.md to understand the overall implementation plan. `n2. Check which tasks are completed [x] and which are pending [ ]. `n3. When a task is completed, update task.md by marking the task as completed [x]. `n4. If a new task is identified that isn't in task.md, add it to the appropriate section. `n5. Always consider dependencies between tasks, and implement them in a logical order."
        }
    )
}

# Convert to JSON and save to .cursor\rules\task_management.json
$taskManagementRule | ConvertTo-Json -Depth 10 | Out-File -FilePath ".cursor\rules\task_management.json"
Write-Host "Task Management System rule saved to .cursor\rules\task_management.json" -ForegroundColor Green

Write-Host "`nAll done! Now you can run 'task-master init' again." -ForegroundColor Cyan
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Read-Host 