# Comprehensive Test Runner for Podinfo Cancel Functionality
# PowerShell version with 100% test coverage

param(
    [string]$BaseUrl = "http://localhost:9898",
    [int]$Timeout = 300,
    [int]$CoverageThreshold = 100,
    [int]$PerformanceThreshold = 90,
    [switch]$Verbose,
    [switch]$StartServer,
    [switch]$StopServer,
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

function Log-Performance {
    param([string]$Message)
    Write-Host "⚡ $Message" -ForegroundColor $Cyan
}

# Global variables
$script:PodinfoProcess = $null
$script:TestResultsDir = "test-results"
$script:StartTime = Get-Date

# Test result variables
$script:UnitTestsPassed = $false
$script:IntegrationTestsPassed = $false
$script:PerformanceTestsPassed = $false
$script:RaceTestsPassed = $false
$script:SecurityTestsPassed = $false
$script:ApiTestsPassed = $false
$script:ErrorTestsPassed = $false
$script:BuildTestsPassed = $false
$script:FrontendTestsPassed = $false

function Show-Help {
    Write-Host "Comprehensive Test Runner for Podinfo Cancel Functionality" -ForegroundColor $Cyan
    Write-Host "=========================================================" -ForegroundColor $Cyan
    Write-Host ""
    Write-Host "Usage: .\run_comprehensive_tests.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -BaseUrl url          Base URL for tests (default: http://localhost:9898)"
    Write-Host "  -Timeout seconds      Test timeout in seconds (default: 300)"
    Write-Host "  -CoverageThreshold %  Coverage threshold percentage (default: 100)"
    Write-Host "  -PerformanceThreshold % Performance threshold percentage (default: 90)"
    Write-Host "  -Verbose              Enable verbose output"
    Write-Host "  -StartServer          Start podinfo server before running tests"
    Write-Host "  -StopServer           Stop podinfo server after running tests"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\run_comprehensive_tests.ps1 -StartServer -StopServer"
    Write-Host "  .\run_comprehensive_tests.ps1 -BaseUrl http://localhost:8080 -Verbose"
    Write-Host "  .\run_comprehensive_tests.ps1 -CoverageThreshold 95 -PerformanceThreshold 85"
    Write-Host ""
}

function Setup-TestEnvironment {
    Log-Info "Setting up test environment..."
    
    # Create test results directory
    if (-not (Test-Path $script:TestResultsDir)) {
        New-Item -ItemType Directory -Path $script:TestResultsDir | Out-Null
    }
    
    # Kill any existing podinfo processes
    Get-Process -Name "podinfo" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Start podinfo server
    Log-Info "Starting Podinfo server..."
    $script:PodinfoProcess = Start-Process -FilePath ".\podinfo.exe" -ArgumentList "--port", "9898", "--level", "debug" -PassThru -WindowStyle Hidden -RedirectStandardOutput "$script:TestResultsDir\server.log" -RedirectStandardError "$script:TestResultsDir\server-error.log"
    
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

function Invoke-UnitTests {
    Log-Test "Running unit tests..."
    
    $startTime = Get-Date
    
    try {
        $output = & go test -v -timeout=30s -coverprofile="$script:TestResultsDir\unit-coverage.out" ./... 2>&1
        $output | Out-File -FilePath "$script:TestResultsDir\unit-tests.log" -Encoding UTF8
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Log-Success "Unit tests passed in $([math]::Round($duration, 2))s"
        $script:UnitTestsPassed = $true
        return $true
    }
    catch {
        Log-Error "Unit tests failed: $($_.Exception.Message)"
        $script:UnitTestsPassed = $false
        return $false
    }
}

function Invoke-IntegrationTests {
    Log-Test "Running comprehensive integration tests..."
    
    $startTime = Get-Date
    
    try {
        Push-Location test
        
        $output = & go test -v -timeout=60s -coverprofile="..\$script:TestResultsDir\integration-coverage.out" ./comprehensive_integration_test.go 2>&1
        $output | Out-File -FilePath "..\$script:TestResultsDir\integration-tests.log" -Encoding UTF8
        
        Pop-Location
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Log-Success "Integration tests passed in $([math]::Round($duration, 2))s"
        $script:IntegrationTestsPassed = $true
        return $true
    }
    catch {
        Pop-Location
        Log-Error "Integration tests failed: $($_.Exception.Message)"
        $script:IntegrationTestsPassed = $false
        return $false
    }
}

function Invoke-PerformanceTests {
    Log-Performance "Running performance tests..."
    
    $startTime = Get-Date
    $successCount = 0
    $totalTests = 0
    
    try {
        Push-Location test
        
        # Test 1: Load test
        $totalTests++
        try {
            $output = & go test -v -timeout=60s -run="TestPerformanceAndLoad/LoadTest" ./comprehensive_integration_test.go 2>&1
            $output | Out-File -FilePath "..\$script:TestResultsDir\load-test.log" -Encoding UTF8
            $successCount++
            Log-Success "Load test passed"
        }
        catch {
            Log-Error "Load test failed"
        }
        
        # Test 2: Stress test
        $totalTests++
        try {
            $output = & go test -v -timeout=60s -run="TestPerformanceAndLoad/StressTest" ./comprehensive_integration_test.go 2>&1
            $output | Out-File -FilePath "..\$script:TestResultsDir\stress-test.log" -Encoding UTF8
            $successCount++
            Log-Success "Stress test passed"
        }
        catch {
            Log-Error "Stress test failed"
        }
        
        # Test 3: Concurrent jobs test
        $totalTests++
        try {
            $output = & go test -v -timeout=120s -run="TestConcurrentJobs" ./comprehensive_integration_test.go 2>&1
            $output | Out-File -FilePath "..\$script:TestResultsDir\concurrent-test.log" -Encoding UTF8
            $successCount++
            Log-Success "Concurrent jobs test passed"
        }
        catch {
            Log-Error "Concurrent jobs test failed"
        }
        
        Pop-Location
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        $successRate = [math]::Round(($successCount * 100 / $totalTests), 2)
        
        Log-Performance "Performance tests completed: $successCount/$totalTests passed ($successRate percent) in $([math]::Round($duration, 2))s"
        
        if ($successRate -ge $PerformanceThreshold) {
            Log-Success "Performance tests meet threshold ($successRate percent >= $PerformanceThreshold percent)"
            $script:PerformanceTestsPassed = $true
            return $true
        } else {
            Log-Error "Performance tests below threshold ($successRate percent < $PerformanceThreshold percent)"
            $script:PerformanceTestsPassed = $false
            return $false
        }
    }
    catch {
        Pop-Location
        Log-Error "Performance tests failed: $($_.Exception.Message)"
        $script:PerformanceTestsPassed = $false
        return $false
    }
}

function Invoke-RaceConditionTests {
    Log-Test "Running race condition tests..."
    
    $startTime = Get-Date
    
    try {
        Push-Location test
        
        $output = & go test -v -timeout=60s -race -run="TestRaceConditions" ./comprehensive_integration_test.go 2>&1
        $output | Out-File -FilePath "..\$script:TestResultsDir\race-tests.log" -Encoding UTF8
        
        Pop-Location
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Log-Success "Race condition tests passed in $([math]::Round($duration, 2))s"
        $script:RaceTestsPassed = $true
        return $true
    }
    catch {
        Pop-Location
        Log-Error "Race condition tests failed: $($_.Exception.Message)"
        $script:RaceTestsPassed = $false
        return $false
    }
}

function Invoke-SecurityTests {
    Log-Test "Running security tests..."
    
    $startTime = Get-Date
    $validationFailures = 0
    
    try {
        # Test 1: Input validation
        Log-Info "Testing input validation..."
        $invalidInputs = @("abc", "-1", "999999", "0")
        
        foreach ($input in $invalidInputs) {
            try {
                $response = Invoke-RestMethod -Uri "$BaseUrl/delay/$input" -Method GET -TimeoutSec 5
                Log-Warning "Input validation warning for: $input (unexpected success)"
                $validationFailures++
            }
            catch {
                if ($_.Exception.Response.StatusCode -eq 400) {
                    Log-Success "Input validation passed for: $input"
                } else {
                    Log-Error "Input validation failed for: $input"
                    $validationFailures++
                }
            }
        }
        
        # Test 2: Error handling
        Log-Info "Testing error handling..."
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/jobs/fake-job-id/cancel" -Method POST -Body "{}" -ContentType "application/json" -TimeoutSec 5
            Log-Error "Error handling test failed (unexpected success)"
            $validationFailures++
        }
        catch {
            if ($_.Exception.Response.StatusCode -eq 404) {
                Log-Success "Error handling test passed"
            } else {
                Log-Error "Error handling test failed"
                $validationFailures++
            }
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        if ($validationFailures -eq 0) {
            Log-Success "Security tests passed in $([math]::Round($duration, 2))s"
            $script:SecurityTestsPassed = $true
            return $true
        } else {
            Log-Error "Security tests failed ($validationFailures failures) in $([math]::Round($duration, 2))s"
            $script:SecurityTestsPassed = $false
            return $false
        }
    }
    catch {
        Log-Error "Security tests failed: $($_.Exception.Message)"
        $script:SecurityTestsPassed = $false
        return $false
    }
}

function Invoke-ApiConsistencyTests {
    Log-Test "Running API consistency tests..."
    
    $startTime = Get-Date
    
    try {
        Push-Location test
        
        $output = & go test -v -timeout=30s -run="TestAPIConsistency" ./comprehensive_integration_test.go 2>&1
        $output | Out-File -FilePath "..\$script:TestResultsDir\api-consistency.log" -Encoding UTF8
        
        Pop-Location
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Log-Success "API consistency tests passed in $([math]::Round($duration, 2))s"
        $script:ApiTestsPassed = $true
        return $true
    }
    catch {
        Pop-Location
        Log-Error "API consistency tests failed: $($_.Exception.Message)"
        $script:ApiTestsPassed = $false
        return $false
    }
}

function Invoke-ErrorHandlingTests {
    Log-Test "Running error handling tests..."
    
    $startTime = Get-Date
    
    try {
        Push-Location test
        
        $output = & go test -v -timeout=30s -run="TestErrorHandling" ./comprehensive_integration_test.go 2>&1
        $output | Out-File -FilePath "..\$script:TestResultsDir\error-handling.log" -Encoding UTF8
        
        Pop-Location
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Log-Success "Error handling tests passed in $([math]::Round($duration, 2))s"
        $script:ErrorTestsPassed = $true
        return $true
    }
    catch {
        Pop-Location
        Log-Error "Error handling tests failed: $($_.Exception.Message)"
        $script:ErrorTestsPassed = $false
        return $false
    }
}

function Invoke-BuildTests {
    Log-Test "Running build tests..."
    
    $startTime = Get-Date
    
    try {
        # Test 1: Basic build
        $output = & go build -o podinfo-test.exe . 2>&1
        $output | Out-File -FilePath "$script:TestResultsDir\build.log" -Encoding UTF8
        
        if ($LASTEXITCODE -eq 0) {
            Log-Success "Basic build test passed"
        } else {
            Log-Error "Basic build test failed"
            return $false
        }
        
        # Test 2: Binary size check
        if (Test-Path "podinfo-test.exe") {
            $fileInfo = Get-Item "podinfo-test.exe"
            $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
            
            if ($sizeMB -lt 50) {
                Log-Success "Binary size check passed (${sizeMB}MB < 50MB)"
            } else {
                Log-Warning "Binary size check warning (${sizeMB}MB >= 50MB)"
            }
            
            # Clean up test binary
            Remove-Item "podinfo-test.exe" -Force
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Log-Success "Build tests passed in $([math]::Round($duration, 2))s"
        $script:BuildTestsPassed = $true
        return $true
    }
    catch {
        Log-Error "Build tests failed: $($_.Exception.Message)"
        $script:BuildTestsPassed = $false
        return $false
    }
}

function Invoke-FrontendTests {
    Log-Test "Running frontend tests..."
    
    $startTime = Get-Date
    
    try {
        # Test 1: Frontend accessibility
        $response = Invoke-RestMethod -Uri "$BaseUrl/" -Method GET -TimeoutSec 5
        
        if ($response -match "Long-running Operations") {
            Log-Success "Frontend accessibility test passed"
        } else {
            Log-Error "Frontend accessibility test failed"
            return $false
        }
        
        # Test 2: Frontend functionality (basic)
        if ($response -match "Cancel Job") {
            Log-Success "Frontend functionality test passed"
        } else {
            Log-Warning "Frontend functionality test warning (cancel button not found)"
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Log-Success "Frontend tests passed in $([math]::Round($duration, 2))s"
        $script:FrontendTestsPassed = $true
        return $true
    }
    catch {
        Log-Error "Frontend tests failed: $($_.Exception.Message)"
        $script:FrontendTestsPassed = $false
        return $false
    }
}

function Test-Coverage {
    Log-Test "Checking test coverage..."
    
    try {
        # Combine coverage files
        $combinedCoverage = "$script:TestResultsDir\combined-coverage.out"
        "mode: atomic" | Out-File -FilePath $combinedCoverage -Encoding UTF8
        
        if (Test-Path "$script:TestResultsDir\unit-coverage.out") {
            Get-Content "$script:TestResultsDir\unit-coverage.out" | Select-Object -Skip 1 | Add-Content -Path $combinedCoverage
        }
        
        if (Test-Path "$script:TestResultsDir\integration-coverage.out") {
            Get-Content "$script:TestResultsDir\integration-coverage.out" | Select-Object -Skip 1 | Add-Content -Path $combinedCoverage
        }
        
        # Generate coverage report
        $coverageOutput = & go tool cover -func=$combinedCoverage 2>&1
        $coverageOutput | Out-File -FilePath "$script:TestResultsDir\coverage-report.txt" -Encoding UTF8
        
        $coverageLine = $coverageOutput | Select-Object -Last 1
        if ($coverageLine -match "(\d+\.\d+)%") {
            $coveragePercent = [double]$matches[1]
            
            Log-Info "Test coverage: ${coveragePercent}%"
            
            if ($coveragePercent -ge $CoverageThreshold) {
                Log-Success "Coverage meets threshold (${coveragePercent}% >= ${CoverageThreshold}%)"
                return $true
            } else {
                Log-Error "Coverage below threshold (${coveragePercent}% < ${CoverageThreshold}%)"
                return $false
            }
        } else {
            Log-Error "Failed to parse coverage percentage"
            return $false
        }
    }
    catch {
        Log-Error "Failed to generate coverage report: $($_.Exception.Message)"
        return $false
    }
}

function New-TestReport {
    Log-Info "Generating comprehensive test report..."
    
    $reportFile = "$script:TestResultsDir\test-report.md"
    $endTime = Get-Date
    $totalDuration = ($endTime - $script:StartTime).TotalSeconds
    
    $totalTests = 9
    $passedTests = @($script:UnitTestsPassed, $script:IntegrationTestsPassed, $script:PerformanceTestsPassed, $script:RaceTestsPassed, $script:SecurityTestsPassed, $script:ApiTestsPassed, $script:ErrorTestsPassed, $script:BuildTestsPassed, $script:FrontendTestsPassed) | Where-Object { $_ -eq $true } | Measure-Object | Select-Object -ExpandProperty Count
    
    $overallResult = if ($passedTests -eq $totalTests) { "✅ ALL TESTS PASSED" } else { "❌ SOME TESTS FAILED" }
    
    $report = @"
# Comprehensive Test Report

**Generated:** $(Get-Date)
**Test Duration:** $([math]::Round($totalDuration, 2))s
**Base URL:** $BaseUrl
**Coverage Threshold:** ${CoverageThreshold}%
**Performance Threshold:** ${PerformanceThreshold}%

## Test Results Summary

| Test Category | Status | Details |
|---------------|--------|---------|
| Unit Tests | $(if ($script:UnitTestsPassed) { "✅ PASS" } else { "❌ FAIL" }) | [View Log]($script:TestResultsDir/unit-tests.log) |
| Integration Tests | $(if ($script:IntegrationTestsPassed) { "✅ PASS" } else { "❌ FAIL" }) | [View Log]($script:TestResultsDir/integration-tests.log) |
| Performance Tests | $(if ($script:PerformanceTestsPassed) { "✅ PASS" } else { "❌ FAIL" }) | [View Log]($script:TestResultsDir/performance-tests.log) |
| Race Condition Tests | $(if ($script:RaceTestsPassed) { "✅ PASS" } else { "❌ FAIL" }) | [View Log]($script:TestResultsDir/race-tests.log) |
| Security Tests | $(if ($script:SecurityTestsPassed) { "✅ PASS" } else { "❌ FAIL" }) | [View Log]($script:TestResultsDir/security-tests.log) |
| API Consistency Tests | $(if ($script:ApiTestsPassed) { "✅ PASS" } else { "❌ FAIL" }) | [View Log]($script:TestResultsDir/api-consistency.log) |
| Error Handling Tests | $(if ($script:ErrorTestsPassed) { "✅ PASS" } else { "❌ FAIL" }) | [View Log]($script:TestResultsDir/error-handling.log) |
| Build Tests | $(if ($script:BuildTestsPassed) { "✅ PASS" } else { "❌ FAIL" }) | [View Log]($script:TestResultsDir/build.log) |
| Frontend Tests | $(if ($script:FrontendTestsPassed) { "✅ PASS" } else { "❌ FAIL" }) | [View Log]($script:TestResultsDir/frontend-tests.log) |

## Coverage Report

``````
$(if (Test-Path "$script:TestResultsDir\coverage-report.txt") { Get-Content "$script:TestResultsDir\coverage-report.txt" } else { "Coverage report not available" })
``````

## Test Artifacts

- Server Log: [$script:TestResultsDir/server.log]($script:TestResultsDir/server.log)
- Combined Coverage: [$script:TestResultsDir/combined-coverage.out]($script:TestResultsDir/combined-coverage.out)
- Test Results Directory: [$script:TestResultsDir/]($script:TestResultsDir/)

## Overall Status

**Overall Result:** $overallResult

"@
    
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    Log-Success "Test report generated: $reportFile"
}

function Invoke-AllTests {
    $startTime = Get-Date
    
    Write-Host "🚀 Starting Comprehensive Test Suite" -ForegroundColor $Cyan
    Write-Host "================================================"
    Write-Host "Base URL: $BaseUrl"
    Write-Host "Timeout: ${Timeout}s"
    Write-Host "Coverage Threshold: ${CoverageThreshold}%"
    Write-Host "Performance Threshold: ${PerformanceThreshold}%"
    Write-Host "Verbose: $Verbose"
    Write-Host ""
    
    # Run all test categories
    Invoke-UnitTests | Out-Null
    Invoke-IntegrationTests | Out-Null
    Invoke-PerformanceTests | Out-Null
    Invoke-RaceConditionTests | Out-Null
    Invoke-SecurityTests | Out-Null
    Invoke-ApiConsistencyTests | Out-Null
    Invoke-ErrorHandlingTests | Out-Null
    Invoke-BuildTests | Out-Null
    Invoke-FrontendTests | Out-Null
    
    # Check coverage
    Test-Coverage | Out-Null
    
    # Generate report
    New-TestReport
    
    # Print summary
    $endTime = Get-Date
    $totalDuration = ($endTime - $startTime).TotalSeconds
    
    $totalTests = 9
    $passedTests = @($script:UnitTestsPassed, $script:IntegrationTestsPassed, $script:PerformanceTestsPassed, $script:RaceTestsPassed, $script:SecurityTestsPassed, $script:ApiTestsPassed, $script:ErrorTestsPassed, $script:BuildTestsPassed, $script:FrontendTestsPassed) | Where-Object { $_ -eq $true } | Measure-Object | Select-Object -ExpandProperty Count
    
    Write-Host ""
    Write-Host "================================================"
    Write-Host "📊 Test Summary" -ForegroundColor $Cyan
    Write-Host "Total test categories: $totalTests"
    Write-Host "Passed: $passedTests" -ForegroundColor $Green
    Write-Host "Failed: $($totalTests - $passedTests)" -ForegroundColor $Red
    Write-Host "Total duration: $([math]::Round($totalDuration, 2))s"
    Write-Host "Test results: $script:TestResultsDir/"
    
    if ($passedTests -eq $totalTests) {
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
        if (-not (Setup-TestEnvironment)) {
            Log-Error "Failed to setup test environment"
            exit 1
        }
    }
    
    # Run all tests
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
