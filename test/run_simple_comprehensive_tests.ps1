# Simple comprehensive test runner for Windows PowerShell
param(
    [string]$BaseUrl = "http://localhost:9898",
    [switch]$StartServer,
    [switch]$StopServer,
    [switch]$Verbose
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

function Log-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $Red
}

function Log-Test {
    param([string]$Message)
    Write-Host "🧪 $Message" -ForegroundColor $Yellow
}

# Global variables
$script:PodinfoProcess = $null

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
        Log-Success "Server health check passed"
        return $true
    }
    catch {
        Log-Error "Server health check failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-BasicDelayJob {
    Log-Test "Testing basic delay job"
    
    try {
        $startTime = Get-Date
        $response = Invoke-RestMethod -Uri "$BaseUrl/delay/2" -Method GET -TimeoutSec 10
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Log-Success "Basic delay job completed in $([math]::Round($duration, 2))s"
        return $true
    }
    catch {
        Log-Error "Basic delay job failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-FrontendAccess {
    Log-Test "Testing frontend access"
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/" -Method GET -TimeoutSec 5
        
        if ($response -match "Long-running Operations") {
            Log-Success "Frontend with cancel functionality is accessible"
            return $true
        } else {
            Log-Error "Frontend cancel functionality not found"
            return $false
        }
    }
    catch {
        Log-Error "Frontend access failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-ErrorHandling {
    Log-Test "Testing error handling"
    
    try {
        # Test cancel non-existent job
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/jobs/fake-job-id/cancel" -Method POST -Body "{}" -ContentType "application/json" -TimeoutSec 5
            Log-Error "Expected 404 error for non-existent job"
            return $false
        }
        catch {
            if ($_.Exception.Response.StatusCode -eq 404) {
                Log-Success "Error handling test passed - 404 for non-existent job"
                return $true
            } else {
                Log-Error "Unexpected error: $($_.Exception.Message)"
                return $false
            }
        }
    }
    catch {
        Log-Error "Error handling test failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-AllTests {
    $startTime = Get-Date
    $passed = 0
    $failed = 0
    $total = 0
    
    Write-Host "🚀 Starting Comprehensive Test Suite" -ForegroundColor $Cyan
    Write-Host "================================================"
    Write-Host "Base URL: $BaseUrl"
    Write-Host "Verbose: $Verbose"
    Write-Host ""
    
    # Define tests
    $tests = @(
        @{ Name = "Server Health Check"; Function = "Test-ServerHealth" },
        @{ Name = "Basic Delay Job"; Function = "Test-BasicDelayJob" },
        @{ Name = "Frontend Access"; Function = "Test-FrontendAccess" },
        @{ Name = "Error Handling"; Function = "Test-ErrorHandling" }
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
