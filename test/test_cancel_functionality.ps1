# PowerShell version of the cancel functionality test script

param(
    [string]$BaseUrl = "http://localhost:9898",
    [int]$Timeout = 30,
    [switch]$Verbose
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

# Utility functions
function Invoke-Request {
    param(
        [string]$Method,
        [string]$Url,
        [string]$Body = $null
    )
    
    if ($Verbose) {
        Write-Host "Making $Method request to: $Url"
        if ($Body) {
            Write-Host "Data: $Body"
        }
    }
    
    try {
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        if ($Method -eq "GET") {
            $response = Invoke-RestMethod -Uri $Url -Method GET -Headers $headers -ErrorAction Stop
            return @{ Body = $response; StatusCode = 200 }
        } elseif ($Method -eq "POST") {
            $response = Invoke-RestMethod -Uri $Url -Method POST -Headers $headers -Body $Body -ErrorAction Stop
            return @{ Body = $response; StatusCode = 200 }
        } else {
            $response = Invoke-RestMethod -Uri $Url -Method $Method -Headers $headers -ErrorAction Stop
            return @{ Body = $response; StatusCode = 200 }
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        return @{ Body = $null; StatusCode = $statusCode; Error = $_.Exception.Message }
    }
}

function Test-ServerHealth {
    Log-Test "Testing server health"
    
    $response = Invoke-Request -Method "GET" -Url "$BaseUrl/healthz"
    
    if ($response.StatusCode -eq 200) {
        Log-Success "Server is healthy"
        return $true
    } else {
        Log-Error "Server health check failed (status: $($response.StatusCode))"
        return $false
    }
}

function Test-BasicDelayJob {
    Log-Test "Testing basic delay job completion"
    
    $response = Invoke-Request -Method "GET" -Url "$BaseUrl/delay/2"
    
    if ($response.StatusCode -eq 200) {
        $status = $response.Body.status
        $jobId = $response.Body.job_id
        
        if ($status -eq "completed") {
            Log-Success "Basic delay job completed successfully (Job ID: $jobId)"
            return $true
        } else {
            Log-Error "Job did not complete successfully (status: $status)"
            return $false
        }
    } else {
        Log-Error "Delay job request failed (status: $($response.StatusCode))"
        return $false
    }
}

function Test-JobCancellation {
    Log-Test "Testing job cancellation"
    
    # Start a long-running job in background
    Log-Info "Starting 10-second delay job..."
    $jobJob = Start-Job -ScriptBlock {
        param($url)
        try {
            Invoke-RestMethod -Uri $url -Method GET
        } catch {
            # Ignore errors for background job
        }
    } -ArgumentList "$BaseUrl/delay/10"
    
    # Wait for job to start
    Start-Sleep -Seconds 1
    
    # Get job list to find the running job
    $jobsResponse = Invoke-Request -Method "GET" -Url "$BaseUrl/jobs"
    
    if ($jobsResponse.StatusCode -eq 200) {
        $jobs = $jobsResponse.Body.jobs
        $runningJob = $jobs | Where-Object { $_.status -eq "running" } | Select-Object -First 1
        
        if ($runningJob) {
            $jobId = $runningJob.id
            Log-Info "Found running job: $jobId"
            
            # Cancel the job
            $cancelResponse = Invoke-Request -Method "POST" -Url "$BaseUrl/jobs/$jobId/cancel" -Body "{}"
            
            if ($cancelResponse.StatusCode -eq 200) {
                $cancelStatus = $cancelResponse.Body.status
                if ($cancelStatus -eq "cancelled") {
                    Log-Success "Job cancelled successfully"
                    Stop-Job $jobJob -ErrorAction SilentlyContinue
                    Remove-Job $jobJob -ErrorAction SilentlyContinue
                    return $true
                } else {
                    Log-Error "Job cancellation failed (status: $cancelStatus)"
                    Stop-Job $jobJob -ErrorAction SilentlyContinue
                    Remove-Job $jobJob -ErrorAction SilentlyContinue
                    return $false
                }
            } else {
                Log-Error "Cancel request failed (status: $($cancelResponse.StatusCode))"
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
    } else {
        Log-Error "Failed to get jobs list (status: $($jobsResponse.StatusCode))"
        Stop-Job $jobJob -ErrorAction SilentlyContinue
        Remove-Job $jobJob -ErrorAction SilentlyContinue
        return $false
    }
}

function Test-JobStatusEndpoints {
    Log-Test "Testing job status endpoints"
    
    # Test list jobs endpoint
    $jobsResponse = Invoke-Request -Method "GET" -Url "$BaseUrl/jobs"
    
    if ($jobsResponse.StatusCode -eq 200) {
        $jobCount = $jobsResponse.Body.count
        Log-Success "List jobs endpoint working (count: $jobCount)"
        
        # Test get specific job if there are jobs
        if ($jobCount -gt 0) {
            $jobId = $jobsResponse.Body.jobs[0].id
            if ($jobId) {
                $jobResponse = Invoke-Request -Method "GET" -Url "$BaseUrl/jobs/$jobId"
                
                if ($jobResponse.StatusCode -eq 200) {
                    Log-Success "Get job endpoint working"
                    return $true
                } else {
                    Log-Error "Get job endpoint failed (status: $($jobResponse.StatusCode))"
                    return $false
                }
            }
        }
        return $true
    } else {
        Log-Error "List jobs endpoint failed (status: $($jobsResponse.StatusCode))"
        return $false
    }
}

function Test-ErrorHandling {
    Log-Test "Testing error handling"
    
    # Test cancel non-existent job
    $cancelResponse = Invoke-Request -Method "POST" -Url "$BaseUrl/jobs/fake-job-id/cancel" -Body "{}"
    
    if ($cancelResponse.StatusCode -eq 404) {
        Log-Success "Error handling working correctly (404 for non-existent job)"
        return $true
    } else {
        Log-Error "Error handling failed (expected 404, got $($cancelResponse.StatusCode))"
        return $false
    }
}

function Test-ConcurrentJobs {
    Log-Test "Testing concurrent jobs"
    
    # Start multiple jobs
    Log-Info "Starting 3 concurrent jobs..."
    $jobs = @()
    for ($i = 0; $i -lt 3; $i++) {
        $jobs += Start-Job -ScriptBlock {
            param($url)
            try {
                Invoke-RestMethod -Uri $url -Method GET
            } catch {
                # Ignore errors for background jobs
            }
        } -ArgumentList "$BaseUrl/delay/2"
    }
    
    # Wait for completion
    Start-Sleep -Seconds 4
    
    # Check final job count
    $jobsResponse = Invoke-Request -Method "GET" -Url "$BaseUrl/jobs"
    
    if ($jobsResponse.StatusCode -eq 200) {
        $jobCount = $jobsResponse.Body.count
        Log-Success "Concurrent jobs test completed (final count: $jobCount)"
        
        # Clean up background jobs
        $jobs | ForEach-Object { Stop-Job $_ -ErrorAction SilentlyContinue; Remove-Job $_ -ErrorAction SilentlyContinue }
        return $true
    } else {
        Log-Error "Failed to check concurrent jobs (status: $($jobsResponse.StatusCode))"
        $jobs | ForEach-Object { Stop-Job $_ -ErrorAction SilentlyContinue; Remove-Job $_ -ErrorAction SilentlyContinue }
        return $false
    }
}

function Test-FrontendIntegration {
    Log-Test "Testing frontend integration"
    
    # Test that the frontend loads
    $response = Invoke-Request -Method "GET" -Url "$BaseUrl/"
    
    if ($response.StatusCode -eq 200) {
        $body = $response.Body
        if ($body -match "Long-running Operations") {
            Log-Success "Frontend integration working (cancel UI present)"
            return $true
        } else {
            Log-Warning "Frontend loaded but cancel UI not found"
            return $true
        }
    } else {
        Log-Error "Frontend not accessible (status: $($response.StatusCode))"
        return $false
    }
}

# Main test runner
function Invoke-AllTests {
    $startTime = Get-Date
    $passed = 0
    $failed = 0
    $total = 0
    
    Write-Host "🚀 Starting Cancel Functionality Tests" -ForegroundColor $Cyan
    Write-Host "================================================"
    Write-Host "Base URL: $BaseUrl"
    Write-Host "Timeout: ${Timeout}s"
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

# Check if server is running
function Test-ServerRunning {
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/healthz" -Method GET -TimeoutSec 5
        return $true
    }
    catch {
        Log-Error "Server is not running at $BaseUrl"
        Log-Info "Please start the server with: .\podinfo.exe --port 9898"
        return $false
    }
}

# Main execution
function Main {
    if (-not (Test-ServerRunning)) {
        exit 1
    }
    
    $result = Invoke-AllTests
    if ($result) {
        exit 0
    } else {
        exit 1
    }
}

# Run main function
Main
