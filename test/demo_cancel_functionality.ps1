# Demo script to showcase the cancel functionality
# This script demonstrates the key features of the cancel implementation

param(
    [string]$BaseUrl = "http://localhost:9898",
    [switch]$StartServer,
    [switch]$StopServer
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"
$Cyan = "Cyan"

function Log-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor $Blue
}

function Log-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $Green
}

function Log-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor $Yellow
}

function Log-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $Red
}

function Log-Demo {
    param([string]$Message)
    Write-Host "🎬 $Message" -ForegroundColor $Cyan
}

# Global variables
$script:PodinfoProcess = $null

function Start-PodinfoServer {
    Log-Info "Starting Podinfo server for demo..."
    
    # Kill any existing podinfo processes
    Get-Process -Name "podinfo" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Start podinfo server
    $script:PodinfoProcess = Start-Process -FilePath ".\podinfo.exe" -ArgumentList "--port", "9898", "--level", "debug" -PassThru -WindowStyle Hidden
    
    if ($script:PodinfoProcess) {
        Log-Info "Podinfo server started with PID: $($script:PodinfoProcess.Id)"
        
        # Wait for server to be ready
        $maxRetries = 30
        $retryCount = 0
        
        while ($retryCount -lt $maxRetries) {
            try {
                $response = Invoke-RestMethod -Uri "$BaseUrl/healthz" -Method GET -TimeoutSec 2
                Log-Success "Server is ready for demo"
                return $true
            }
            catch {
                $retryCount++
                Log-Info "Waiting for server... (attempt $retryCount/$maxRetries)"
                Start-Sleep -Seconds 1
            }
        }
        
        Log-Error "Server did not start within $maxRetries seconds"
        return $false
    } else {
        Log-Error "Failed to start podinfo server"
        return $false
    }
}

function Stop-PodinfoServer {
    if ($script:PodinfoProcess -and !$script:PodinfoProcess.HasExited) {
        Log-Info "Stopping Podinfo server..."
        Stop-Process -Id $script:PodinfoProcess.Id -Force -ErrorAction SilentlyContinue
        $script:PodinfoProcess.WaitForExit(5000)
        Log-Success "Server stopped"
    }
    
    # Also kill any remaining podinfo processes
    Get-Process -Name "podinfo" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Demo-BasicJobCompletion {
    Log-Demo "Demo 1: Basic Job Completion"
    Write-Host "This demonstrates a normal job that completes successfully." -ForegroundColor Gray
    Write-Host ""
    
    Log-Info "Starting a 3-second delay job..."
    $startTime = Get-Date
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/delay/3" -Method GET -TimeoutSec 10
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Log-Success "Job completed successfully!"
        Write-Host "  Duration: $([math]::Round($duration, 2)) seconds" -ForegroundColor Gray
        Write-Host "  Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
    }
    catch {
        Log-Error "Job failed: $($_.Exception.Message)"
    }
    
    Write-Host ""
}

function Demo-JobCancellation {
    Log-Demo "Demo 2: Job Cancellation"
    Write-Host "This demonstrates cancelling a long-running job before it completes." -ForegroundColor Gray
    Write-Host ""
    
    Log-Info "Starting a 10-second delay job..."
    
    # Start job in background
    $jobJob = Start-Job -ScriptBlock {
        param($url)
        try {
            Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 15
        }
        catch {
            # Expected for cancelled jobs
        }
    } -ArgumentList "$BaseUrl/delay/10"
    
    # Wait for job to start
    Start-Sleep -Seconds 1
    
    try {
        # Get job list
        $jobsResponse = Invoke-RestMethod -Uri "$BaseUrl/jobs" -Method GET
        $runningJob = $jobsResponse.jobs | Where-Object { $_.status -eq "running" } | Select-Object -First 1
        
        if ($runningJob) {
            $jobId = $runningJob.id
            Log-Info "Found running job: $jobId"
            Log-Info "Cancelling job after 2 seconds..."
            
            Start-Sleep -Seconds 2
            
            # Cancel the job
            $cancelResponse = Invoke-RestMethod -Uri "$BaseUrl/jobs/$jobId/cancel" -Method POST -Body "{}" -ContentType "application/json"
            
            if ($cancelResponse.status -eq "cancelled") {
                Log-Success "Job cancelled successfully!"
                Write-Host "  Job ID: $($cancelResponse.job_id)" -ForegroundColor Gray
                Write-Host "  Status: $($cancelResponse.status)" -ForegroundColor Gray
            } else {
                Log-Warning "Job cancellation response: $($cancelResponse | ConvertTo-Json -Compress)"
            }
        } else {
            Log-Warning "No running job found for cancellation demo"
        }
    }
    catch {
        Log-Error "Cancellation demo failed: $($_.Exception.Message)"
    }
    finally {
        # Clean up background job
        Stop-Job $jobJob -ErrorAction SilentlyContinue
        Remove-Job $jobJob -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
}

function Demo-ConcurrentJobs {
    Log-Demo "Demo 3: Concurrent Jobs"
    Write-Host "This demonstrates multiple jobs running simultaneously." -ForegroundColor Gray
    Write-Host ""
    
    Log-Info "Starting 3 concurrent 2-second delay jobs..."
    
    $jobs = @()
    for ($i = 1; $i -le 3; $i++) {
        $jobs += Start-Job -ScriptBlock {
            param($url, $jobNumber)
            try {
                $response = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 10
                return @{ JobNumber = $jobNumber; Success = $true; Response = $response }
            }
            catch {
                return @{ JobNumber = $jobNumber; Success = $false; Error = $_.Exception.Message }
            }
        } -ArgumentList "$BaseUrl/delay/2", $i
    }
    
    # Wait for all jobs to complete
    Log-Info "Waiting for all jobs to complete..."
    $jobs | Wait-Job | Out-Null
    
    # Collect results
    $results = $jobs | Receive-Job
    $successCount = ($results | Where-Object { $_.Success }).Count
    
    Log-Success "Concurrent jobs completed: $successCount/3 successful"
    
    foreach ($result in $results) {
        if ($result.Success) {
            Write-Host "  Job $($result.JobNumber): ✅ Completed" -ForegroundColor Green
        } else {
            Write-Host "  Job $($result.JobNumber): ❌ Failed - $($result.Error)" -ForegroundColor Red
        }
    }
    
    # Clean up
    $jobs | Remove-Job -ErrorAction SilentlyContinue
    
    Write-Host ""
}

function Demo-ErrorHandling {
    Log-Demo "Demo 4: Error Handling"
    Write-Host "This demonstrates proper error handling for invalid requests." -ForegroundColor Gray
    Write-Host ""
    
    Log-Info "Testing cancellation of non-existent job..."
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/jobs/fake-job-id/cancel" -Method POST -Body "{}" -ContentType "application/json"
        Log-Error "Expected 404 error but got response: $($response | ConvertTo-Json -Compress)"
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Log-Success "Error handling working correctly - got expected 404 error"
        } else {
            Log-Error "Unexpected error: $($_.Exception.Message)"
        }
    }
    
    Write-Host ""
}

function Demo-FrontendAccess {
    Log-Demo "Demo 5: Frontend Access"
    Write-Host "This demonstrates accessing the enhanced frontend with cancel functionality." -ForegroundColor Gray
    Write-Host ""
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/" -Method GET
        if ($response -match "Long-running Operations") {
            Log-Success "Frontend is accessible with cancel functionality"
            Write-Host "  Open your browser and navigate to: $BaseUrl" -ForegroundColor Gray
            Write-Host "  Look for the 'Long-running Operations' section" -ForegroundColor Gray
        } else {
            Log-Warning "Frontend loaded but cancel UI not detected"
        }
    }
    catch {
        Log-Error "Frontend access failed: $($_.Exception.Message)"
    }
    
    Write-Host ""
}

function Show-Summary {
    Write-Host "================================================" -ForegroundColor $Cyan
    Write-Host "🎉 Cancel Functionality Demo Complete!" -ForegroundColor $Cyan
    Write-Host "================================================" -ForegroundColor $Cyan
    Write-Host ""
    Write-Host "Key Features Demonstrated:" -ForegroundColor $Yellow
    Write-Host "  ✅ Basic job completion" -ForegroundColor $Green
    Write-Host "  ✅ Job cancellation" -ForegroundColor $Green
    Write-Host "  ✅ Concurrent job processing" -ForegroundColor $Green
    Write-Host "  ✅ Error handling" -ForegroundColor $Green
    Write-Host "  ✅ Frontend integration" -ForegroundColor $Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor $Yellow
    Write-Host "  • Open $BaseUrl in your browser to see the UI" -ForegroundColor Gray
    Write-Host "  • Try the cancel functionality interactively" -ForegroundColor Gray
    Write-Host "  • Run the full test suite: .\test\run_tests.ps1" -ForegroundColor Gray
    Write-Host ""
}

# Main execution
function Main {
    Write-Host "🚀 Podinfo Cancel Functionality Demo" -ForegroundColor $Cyan
    Write-Host "====================================" -ForegroundColor $Cyan
    Write-Host ""
    
    # Set up cleanup
    if ($StopServer) {
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
            Stop-PodinfoServer
        }
    }
    
    # Start server if requested
    if ($StartServer) {
        if (-not (Start-PodinfoServer)) {
            Log-Error "Failed to start server for demo"
            exit 1
        }
    }
    
    # Run demos
    Demo-BasicJobCompletion
    Demo-JobCancellation
    Demo-ConcurrentJobs
    Demo-ErrorHandling
    Demo-FrontendAccess
    
    # Show summary
    Show-Summary
    
    # Stop server if requested
    if ($StopServer) {
        Stop-PodinfoServer
    }
}

# Run main function
Main
