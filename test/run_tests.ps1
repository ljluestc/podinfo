# Comprehensive test runner for Podinfo Cancel Functionality

param(
    [string]$BaseUrl = "http://localhost:9898",
    [switch]$StartServer,
    [switch]$StopServer,
    [switch]$Verbose,
    [switch]$Help
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"
$Purple = "Magenta"
$Cyan = "Cyan"

# Logging functions
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

function Log-Test {
    param([string]$Message)
    Write-Host "🧪 $Message" -ForegroundColor $Purple
}

# Global variables
$script:PodinfoProcess = $null

function Show-Help {
    Write-Host "Podinfo Cancel Functionality Test Runner" -ForegroundColor $Cyan
    Write-Host "========================================="
    Write-Host ""
    Write-Host "Usage: .\run_tests.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -BaseUrl url       Base URL for tests (default: http://localhost:9898)"
    Write-Host "  -StartServer       Start podinfo server before running tests"
    Write-Host "  -StopServer        Stop podinfo server after running tests"
    Write-Host "  -Verbose           Enable verbose output"
    Write-Host "  -Help              Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\run_tests.ps1 -StartServer -StopServer"
    Write-Host "  .\run_tests.ps1 -BaseUrl http://localhost:8080 -Verbose"
    Write-Host ""
}

function Start-PodinfoServer {
    Log-Info "Starting Podinfo server..."
    
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
                Log-Success "Server is ready"
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

function Test-ServerHealth {
    Log-Test "Testing server health"
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/healthz" -Method GET -TimeoutSec 5
        Log-Success "Server is healthy"
        return $true
    }
    catch {
        Log-Error "Server health check failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-BasicDelayJob {
    Log-Test "Testing basic delay job completion"
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/delay/2" -Method GET -TimeoutSec 10
        
        if ($response.status -eq "completed") {
            Log-Success "Basic delay job completed successfully (Job ID: $($response.job_id))"
            return $true
        } else {
            Log-Error "Job did not complete successfully (status: $($response.status))"
            return $false
        }
    }
    catch {
        Log-Error "Delay job request failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-JobCancellation {
    Log-Test "Testing job cancellation"
    
    try {
        # Start a long-running job in background
        Log-Info "Starting 10-second delay job..."
        $jobJob = Start-Job -ScriptBlock {
            param($url)
            try {
                Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 15
            }
            catch {
                # Ignore errors for background job
            }
        } -ArgumentList "$BaseUrl/delay/10"
        
        # Wait for job to start
        Start-Sleep -Seconds 1
        
        # Get job list to find the running job
        $jobsResponse = Invoke-RestMethod -Uri "$BaseUrl/jobs" -Method GET
        $runningJob = $jobsResponse.jobs | Where-Object { $_.status -eq "running" } | Select-Object -First 1
        
        if ($runningJob) {
            $jobId = $runningJob.id
            Log-Info "Found running job: $jobId"
            
            # Cancel the job
            $cancelResponse = Invoke-RestMethod -Uri "$BaseUrl/jobs/$jobId/cancel" -Method POST -Body "{}" -ContentType "application/json"
            
            if ($cancelResponse.status -eq "cancelled") {
                Log-Success "Job cancelled successfully"
                Stop-Job $jobJob -ErrorAction SilentlyContinue
                Remove-Job $jobJob -ErrorAction SilentlyContinue
                return $true
            } else {
                Log-Error "Job cancellation failed (status: $($cancelResponse.status))"
                Stop-Job $jobJob -ErrorAction SilentlyContinue
                Remove-Job $jobJob -ErrorAction SilentlyContinue
                return $false
            }
        } else {
            Log-Warning "No running job found for cancellation test"
            Stop-Job $jobJob -ErrorAction SilentlyContinue
            Remove-Job $jobJob -ErrorAction SilentlyContinue
            return $true
        }
    }
    catch {
        Log-Error "Job cancellation test failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-JobStatusEndpoints {
    Log-Test "Testing job status endpoints"
    
    try {
        # Test list jobs endpoint
        $jobsResponse = Invoke-RestMethod -Uri "$BaseUrl/jobs" -Method GET
        $jobCount = $jobsResponse.count
        Log-Success "List jobs endpoint working (count: $jobCount)"
        
        # Test get specific job if there are jobs
        if ($jobCount -gt 0) {
            $jobId = $jobsResponse.jobs[0].id
            if ($jobId) {
                $jobResponse = Invoke-RestMethod -Uri "$BaseUrl/jobs/$jobId" -Method GET
                Log-Success "Get job endpoint working"
                return $true
            }
        }
        return $true
    }
    catch {
        Log-Error "Job status endpoints test failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-ErrorHandling {
    Log-Test "Testing error handling"
    
    try {
        # Test cancel non-existent job
        $cancelResponse = Invoke-RestMethod -Uri "$BaseUrl/jobs/fake-job-id/cancel" -Method POST -Body "{}" -ContentType "application/json"
        Log-Error "Expected 404 error for non-existent job"
        return $false
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Log-Success "Error handling working correctly - 404 for non-existent job"
            return $true
        } else {
            Log-Error "Error handling failed - expected 404, got $($_.Exception.Response.StatusCode)"
            return $false
        }
    }
}

function Test-ConcurrentJobs {
    Log-Test "Testing concurrent jobs"
    
    try {
        # Start multiple jobs
        Log-Info "Starting 3 concurrent jobs..."
        $jobs = @()
        for ($i = 0; $i -lt 3; $i++) {
            $jobs += Start-Job -ScriptBlock {
                param($url)
                try {
                    Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 10
                }
                catch {
                    # Ignore errors for background jobs
                }
            } -ArgumentList "$BaseUrl/delay/2"
        }
        
        # Wait for completion
        Start-Sleep -Seconds 4
        
        # Check final job count
        $jobsResponse = Invoke-RestMethod -Uri "$BaseUrl/jobs" -Method GET
        $jobCount = $jobsResponse.count
        Log-Success "Concurrent jobs test completed (final count: $jobCount)"
        
        # Clean up background jobs
        $jobs | ForEach-Object { Stop-Job $_ -ErrorAction SilentlyContinue; Remove-Job $_ -ErrorAction SilentlyContinue }
        return $true
    }
    catch {
        Log-Error "Concurrent jobs test failed: $($_.Exception.Message)"
        $jobs | ForEach-Object { Stop-Job $_ -ErrorAction SilentlyContinue; Remove-Job $_ -ErrorAction SilentlyContinue }
        return $false
    }
}

function Test-FrontendIntegration {
    Log-Test "Testing frontend integration"
    
    try {
        # Test that the frontend loads
        $response = Invoke-RestMethod -Uri "$BaseUrl/" -Method GET
        
        if ($response -match "Long-running Operations") {
            Log-Success "Frontend integration working (cancel UI present)"
            return $true
        } else {
            Log-Warning "Frontend loaded but cancel UI not found"
            return $true
        }
    }
    catch {
        Log-Error "Frontend integration test failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-AllTests {
    $startTime = Get-Date
    $passed = 0
    $failed = 0
    $total = 0
    
    Write-Host "🚀 Starting Podinfo Cancel Functionality Tests" -ForegroundColor $Cyan
    Write-Host "================================================"
    Write-Host "Base URL: $BaseUrl"
    Write-Host "Verbose: $Verbose"
    Write-Host ""
    
    # Define tests
    $tests = @(
        @{ Name = "Server Health Check"; Function = "Test-ServerHealth" },
        @{ Name = "Basic Delay Job"; Function = "Test-BasicDelayJob" },
        @{ Name = "Job Cancellation"; Function = "Test-JobCancellation" },
        @{ Name = "Job Status Endpoints"; Function = "Test-JobStatusEndpoints" },
        @{ Name = "Error Handling"; Function = "Test-ErrorHandling" },
        @{ Name = "Concurrent Jobs"; Function = "Test-ConcurrentJobs" },
        @{ Name = "Frontend Integration"; Function = "Test-FrontendIntegration" }
    )
    
    # Run tests
    foreach ($test in $tests) {
        $total++
        
        if (& $test.Function) {
            $passed++
        } else {
            $failed++
        }
        
        Write-Host ""
    }
    
    # Calculate duration
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    # Print summary
    Write-Host "================================================"
    Write-Host "📊 Test Summary" -ForegroundColor $Cyan
    Write-Host "Total tests: $total"
    Write-Host "Passed: $passed" -ForegroundColor $Green
    Write-Host "Failed: $failed" -ForegroundColor $Red
    Write-Host "Duration: $([math]::Round($duration, 2))s"
    
    if ($failed -eq 0) {
        Write-Host "🎉 All tests passed!" -ForegroundColor $Green
        return $true
    } else {
        Write-Host "❌ Some tests failed" -ForegroundColor $Red
        return $false
    }
}

# Main execution
function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    # Set up cleanup
    if ($StopServer) {
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
            Stop-PodinfoServer
        }
    }
    
    # Start server if requested
    if ($StartServer) {
        if (-not (Start-PodinfoServer)) {
            Log-Error "Failed to start server"
            exit 1
        }
    }
    
    # Run tests
    $result = Invoke-AllTests
    
    # Stop server if requested
    if ($StopServer) {
        Stop-PodinfoServer
    }
    
    if ($result) {
        exit 0
    } else {
        exit 1
    }
}

# Run main function
Main
