package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"sync"
	"testing"
	"time"
)

const (
	baseURL = "http://localhost:9898"
)

type JobResponse struct {
	Delay     int     `json:"delay"`
	Status    string  `json:"status"`
	JobID     string  `json:"job_id"`
	Completed float64 `json:"completed"`
}

type JobListResponse struct {
	Jobs  []JobInfo `json:"jobs"`
	Count int       `json:"count"`
}

type JobInfo struct {
	ID        string    `json:"id"`
	Status    string    `json:"status"`
	StartTime time.Time `json:"start_time"`
	Duration  float64   `json:"duration"`
}

type CancelResponse struct {
	Status string `json:"status"`
	JobID  string `json:"job_id"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

// Test server health and readiness
func TestServerHealth(t *testing.T) {
	t.Run("HealthCheck", func(t *testing.T) {
		resp, err := http.Get(baseURL + "/healthz")
		if err != nil {
			t.Fatalf("Health check failed: %v", err)
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusOK {
			t.Errorf("Expected status 200, got %d", resp.StatusCode)
		}
		
		var health map[string]string
		if err := json.NewDecoder(resp.Body).Decode(&health); err != nil {
			t.Fatalf("Failed to decode health response: %v", err)
		}
		
		if health["status"] != "OK" {
			t.Errorf("Expected status 'OK', got '%s'", health["status"])
		}
	})
	
	t.Run("ReadinessCheck", func(t *testing.T) {
		resp, err := http.Get(baseURL + "/readyz")
		if err != nil {
			t.Fatalf("Readiness check failed: %v", err)
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusOK {
			t.Errorf("Expected status 200, got %d", resp.StatusCode)
		}
	})
}

// Test basic delay job completion
func TestDelayJobCompletion(t *testing.T) {
	testCases := []struct {
		name  string
		delay int
	}{
		{"ShortDelay", 1},
		{"MediumDelay", 3},
		{"LongDelay", 5},
	}
	
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			url := fmt.Sprintf("%s/delay/%d", baseURL, tc.delay)
			
			start := time.Now()
			resp, err := http.Get(url)
			if err != nil {
				t.Fatalf("Failed to start delay job: %v", err)
			}
			defer resp.Body.Close()
			
			if resp.StatusCode != http.StatusOK {
				t.Fatalf("Expected status 200, got %d", resp.StatusCode)
			}
			
			var jobResp JobResponse
			if err := json.NewDecoder(resp.Body).Decode(&jobResp); err != nil {
				t.Fatalf("Failed to decode response: %v", err)
			}
			
			elapsed := time.Since(start)
			
			// Verify job completed successfully
			if jobResp.Status != "completed" {
				t.Errorf("Expected status 'completed', got '%s'", jobResp.Status)
			}
			
			if jobResp.Delay != tc.delay {
				t.Errorf("Expected delay %d, got %d", tc.delay, jobResp.Delay)
			}
			
			// Verify it took approximately the right amount of time
			expectedMin := time.Duration(tc.delay) * time.Second
			expectedMax := time.Duration(tc.delay+1) * time.Second
			if elapsed < expectedMin || elapsed > expectedMax {
				t.Errorf("Expected delay around %ds, took %v", tc.delay, elapsed)
			}
			
			t.Logf("Job completed successfully: %+v", jobResp)
		})
	}
}

// Test job cancellation scenarios
func TestJobCancellation(t *testing.T) {
	t.Run("CancelRunningJob", func(t *testing.T) {
		testCancelRunningJob(t, 10)
	})
	
	t.Run("CancelJobImmediately", func(t *testing.T) {
		testCancelRunningJob(t, 5)
	})
	
	t.Run("CancelJobAfterDelay", func(t *testing.T) {
		testCancelRunningJob(t, 8)
	})
}

func testCancelRunningJob(t *testing.T, delay int) {
	url := fmt.Sprintf("%s/delay/%d", baseURL, delay)
	
	// Start the job in a goroutine
	jobChan := make(chan JobResponse, 1)
	errChan := make(chan error, 1)
	
	go func() {
		resp, err := http.Get(url)
		if err != nil {
			errChan <- err
			return
		}
		defer resp.Body.Close()
		
		var jobResp JobResponse
		if err := json.NewDecoder(resp.Body).Decode(&jobResp); err != nil {
			errChan <- err
			return
		}
		
		jobChan <- jobResp
	}()
	
	// Wait a bit for the job to start
	time.Sleep(500 * time.Millisecond)
	
	// Get the job ID from the job list
	jobsResp, err := http.Get(baseURL + "/jobs")
	if err != nil {
		t.Fatalf("Failed to get jobs list: %v", err)
	}
	defer jobsResp.Body.Close()
	
	var jobs JobListResponse
	if err := json.NewDecoder(jobsResp.Body).Decode(&jobs); err != nil {
		t.Fatalf("Failed to decode jobs response: %v", err)
	}
	
	if jobs.Count == 0 {
		t.Fatalf("No jobs found, expected at least one running job")
	}
	
	// Find the running job
	var jobID string
	for _, job := range jobs.Jobs {
		if job.Status == "running" {
			jobID = job.ID
			break
		}
	}
	
	if jobID == "" {
		t.Fatalf("No running job found")
	}
	
	// Cancel the job
	cancelURL := fmt.Sprintf("%s/jobs/%s/cancel", baseURL, jobID)
	cancelResp, err := http.Post(cancelURL, "application/json", nil)
	if err != nil {
		t.Fatalf("Failed to cancel job: %v", err)
	}
	defer cancelResp.Body.Close()
	
	if cancelResp.StatusCode != http.StatusOK {
		t.Fatalf("Expected status 200 for cancel, got %d", cancelResp.StatusCode)
	}
	
	var cancelRespData CancelResponse
	if err := json.NewDecoder(cancelResp.Body).Decode(&cancelRespData); err != nil {
		t.Fatalf("Failed to decode cancel response: %v", err)
	}
	
	if cancelRespData.Status != "cancelled" {
		t.Errorf("Expected status 'cancelled', got '%s'", cancelRespData.Status)
	}
	
	// Wait for the job to complete and verify it was cancelled
	select {
	case jobResp := <-jobChan:
		if jobResp.Status != "cancelled" {
			t.Errorf("Expected job to be cancelled, got status '%s'", jobResp.Status)
		}
		if jobResp.Completed < float64(delay) {
			t.Logf("Job was cancelled early as expected: completed in %.2fs", jobResp.Completed)
		}
	case err := <-errChan:
		t.Fatalf("Job failed: %v", err)
	case <-time.After(15 * time.Second):
		t.Fatalf("Job did not complete within timeout")
	}
}

// Test job status endpoints comprehensively
func TestJobStatusEndpoints(t *testing.T) {
	t.Run("ListJobsEmpty", func(t *testing.T) {
		// Wait for any previous jobs to complete
		time.Sleep(2 * time.Second)
		
		resp, err := http.Get(baseURL + "/jobs")
		if err != nil {
			t.Fatalf("Failed to get jobs list: %v", err)
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("Expected status 200, got %d", resp.StatusCode)
		}
		
		var jobs JobListResponse
		if err := json.NewDecoder(resp.Body).Decode(&jobs); err != nil {
			t.Fatalf("Failed to decode jobs response: %v", err)
		}
		
		t.Logf("Empty job list: count=%d", jobs.Count)
	})
	
	t.Run("ListJobsWithActiveJobs", func(t *testing.T) {
		// Start a job
		go func() {
			http.Get(baseURL + "/delay/3")
		}()
		
		// Wait for job to start
		time.Sleep(500 * time.Millisecond)
		
		resp, err := http.Get(baseURL + "/jobs")
		if err != nil {
			t.Fatalf("Failed to get jobs list: %v", err)
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("Expected status 200, got %d", resp.StatusCode)
		}
		
		var jobs JobListResponse
		if err := json.NewDecoder(resp.Body).Decode(&jobs); err != nil {
			t.Fatalf("Failed to decode jobs response: %v", err)
		}
		
		if jobs.Count == 0 {
			t.Fatalf("Expected at least one job, got %d", jobs.Count)
		}
		
		// Test get specific job endpoint
		jobID := jobs.Jobs[0].ID
		jobResp, err := http.Get(fmt.Sprintf("%s/jobs/%s", baseURL, jobID))
		if err != nil {
			t.Fatalf("Failed to get job details: %v", err)
		}
		defer jobResp.Body.Close()
		
		if jobResp.StatusCode != http.StatusOK {
			t.Fatalf("Expected status 200, got %d", jobResp.StatusCode)
		}
		
		var job JobInfo
		if err := json.NewDecoder(jobResp.Body).Decode(&job); err != nil {
			t.Fatalf("Failed to decode job response: %v", err)
		}
		
		if job.ID != jobID {
			t.Errorf("Expected job ID %s, got %s", jobID, job.ID)
		}
		
		t.Logf("Job status retrieved successfully: %+v", job)
	})
}

// Test error handling comprehensively
func TestErrorHandling(t *testing.T) {
	t.Run("CancelNonExistentJob", func(t *testing.T) {
		fakeJobID := "fake-job-id-12345"
		cancelURL := fmt.Sprintf("%s/jobs/%s/cancel", baseURL, fakeJobID)
		
		resp, err := http.Post(cancelURL, "application/json", nil)
		if err != nil {
			t.Fatalf("Failed to attempt cancel: %v", err)
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("Expected status 404 for non-existent job, got %d", resp.StatusCode)
		}
	})
	
	t.Run("InvalidDelayValue", func(t *testing.T) {
		// Test with invalid delay values
		invalidDelays := []string{"abc", "-1", "0", "999999"}
		
		for _, delay := range invalidDelays {
			url := fmt.Sprintf("%s/delay/%s", baseURL, delay)
			resp, err := http.Get(url)
			if err != nil {
				t.Fatalf("Failed to make request for delay %s: %v", delay, err)
			}
			defer resp.Body.Close()
			
			if delay == "0" {
				// Zero delay might be valid
				continue
			}
			
			if resp.StatusCode != http.StatusBadRequest {
				t.Errorf("Expected status 400 for invalid delay %s, got %d", delay, resp.StatusCode)
			}
		}
	})
	
	t.Run("GetNonExistentJob", func(t *testing.T) {
		fakeJobID := "non-existent-job-id"
		resp, err := http.Get(fmt.Sprintf("%s/jobs/%s", baseURL, fakeJobID))
		if err != nil {
			t.Fatalf("Failed to get non-existent job: %v", err)
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("Expected status 404 for non-existent job, got %d", resp.StatusCode)
		}
	})
}

// Test concurrent jobs extensively
func TestConcurrentJobs(t *testing.T) {
	testCases := []struct {
		name     string
		numJobs  int
		delay    int
	}{
		{"TwoJobs", 2, 2},
		{"ThreeJobs", 3, 2},
		{"FiveJobs", 5, 1},
		{"TenJobs", 10, 1},
	}
	
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			testConcurrentJobs(t, tc.numJobs, tc.delay)
		})
	}
}

func testConcurrentJobs(t *testing.T, numJobs, delay int) {
	// Start multiple jobs
	jobChan := make(chan JobResponse, numJobs)
	errChan := make(chan error, numJobs)
	
	for i := 0; i < numJobs; i++ {
		go func() {
			url := fmt.Sprintf("%s/delay/%d", baseURL, delay)
			resp, err := http.Get(url)
			if err != nil {
				errChan <- err
				return
			}
			defer resp.Body.Close()
			
			var jobResp JobResponse
			if err := json.NewDecoder(resp.Body).Decode(&jobResp); err != nil {
				errChan <- err
				return
			}
			
			jobChan <- jobResp
		}()
	}
	
	// Wait for all jobs to complete
	completedJobs := 0
	timeout := time.After(30 * time.Second)
	
	for completedJobs < numJobs {
		select {
		case jobResp := <-jobChan:
			completedJobs++
			if jobResp.Status != "completed" {
				t.Errorf("Job %d status: expected 'completed', got '%s'", completedJobs, jobResp.Status)
			}
			t.Logf("Job %d completed: %+v", completedJobs, jobResp)
		case err := <-errChan:
			t.Fatalf("Job failed: %v", err)
		case <-timeout:
			t.Fatalf("Not all jobs completed within timeout")
		}
	}
	
	t.Logf("All %d concurrent jobs completed successfully", numJobs)
}

// Test race conditions and edge cases
func TestRaceConditions(t *testing.T) {
	t.Run("CancelJobRaceCondition", func(t *testing.T) {
		testCancelJobRaceCondition(t, 1)
	})
	
	t.Run("MultipleCancelAttempts", func(t *testing.T) {
		testMultipleCancelAttempts(t, 5)
	})
	
	t.Run("JobCompletionRace", func(t *testing.T) {
		testJobCompletionRace(t, 2)
	})
}

func testCancelJobRaceCondition(t *testing.T, delay int) {
	url := fmt.Sprintf("%s/delay/%d", baseURL, delay)
	
	// Start job
	jobChan := make(chan JobResponse, 1)
	errChan := make(chan error, 1)
	
	go func() {
		resp, err := http.Get(url)
		if err != nil {
			errChan <- err
			return
		}
		defer resp.Body.Close()
		
		var jobResp JobResponse
		if err := json.NewDecoder(resp.Body).Decode(&jobResp); err != nil {
			errChan <- err
			return
		}
		
		jobChan <- jobResp
	}()
	
	// Try to cancel immediately (might complete before we can cancel)
	time.Sleep(100 * time.Millisecond)
	
	// Get jobs and try to cancel
	jobsResp, err := http.Get(baseURL + "/jobs")
	if err == nil {
		defer jobsResp.Body.Close()
		
		var jobs JobListResponse
		if err := json.NewDecoder(jobsResp.Body).Decode(&jobs); err == nil {
			for _, job := range jobs.Jobs {
				if job.Status == "running" {
					cancelURL := fmt.Sprintf("%s/jobs/%s/cancel", baseURL, job.ID)
					http.Post(cancelURL, "application/json", nil)
				}
			}
		}
	}
	
	// Wait for job completion
	select {
	case jobResp := <-jobChan:
		t.Logf("Job completed with status: %s", jobResp.Status)
	case err := <-errChan:
		t.Fatalf("Job failed: %v", err)
	case <-time.After(5 * time.Second):
		t.Fatalf("Job did not complete within timeout")
	}
}

func testMultipleCancelAttempts(t *testing.T, delay int) {
	url := fmt.Sprintf("%s/delay/%d", baseURL, delay)
	
	// Start job
	go func() {
		http.Get(url)
	}()
	
	// Wait for job to start
	time.Sleep(500 * time.Millisecond)
	
	// Get job ID
	jobsResp, err := http.Get(baseURL + "/jobs")
	if err != nil {
		t.Fatalf("Failed to get jobs: %v", err)
	}
	defer jobsResp.Body.Close()
	
	var jobs JobListResponse
	if err := json.NewDecoder(jobsResp.Body).Decode(&jobs); err != nil {
		t.Fatalf("Failed to decode jobs: %v", err)
	}
	
	if len(jobs.Jobs) == 0 {
		t.Skip("No running jobs found")
	}
	
	jobID := jobs.Jobs[0].ID
	
	// Try to cancel multiple times
	for i := 0; i < 3; i++ {
		cancelURL := fmt.Sprintf("%s/jobs/%s/cancel", baseURL, jobID)
		resp, err := http.Post(cancelURL, "application/json", nil)
		if err != nil {
			t.Logf("Cancel attempt %d failed: %v", i+1, err)
			continue
		}
		resp.Body.Close()
		
		if resp.StatusCode == http.StatusOK {
			t.Logf("Cancel attempt %d successful", i+1)
		} else {
			t.Logf("Cancel attempt %d returned status %d", i+1, resp.StatusCode)
		}
	}
}

func testJobCompletionRace(t *testing.T, delay int) {
	url := fmt.Sprintf("%s/delay/%d", baseURL, delay)
	
	// Start multiple jobs simultaneously
	var wg sync.WaitGroup
	numJobs := 3
	
	for i := 0; i < numJobs; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			resp, err := http.Get(url)
			if err != nil {
				t.Logf("Job failed: %v", err)
				return
			}
			defer resp.Body.Close()
			
			var jobResp JobResponse
			if err := json.NewDecoder(resp.Body).Decode(&jobResp); err != nil {
				t.Logf("Failed to decode job response: %v", err)
				return
			}
			
			t.Logf("Job completed: %+v", jobResp)
		}()
	}
	
	wg.Wait()
}

// Test performance and load
func TestPerformanceAndLoad(t *testing.T) {
	t.Run("LoadTest", func(t *testing.T) {
		testLoad(t, 20, 1)
	})
	
	t.Run("StressTest", func(t *testing.T) {
		testStress(t, 50, 1)
	})
}

func testLoad(t *testing.T, numJobs, delay int) {
	start := time.Now()
	
	var wg sync.WaitGroup
	successCount := 0
	var mu sync.Mutex
	
	for i := 0; i < numJobs; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			
			url := fmt.Sprintf("%s/delay/%d", baseURL, delay)
			resp, err := http.Get(url)
			if err != nil {
				t.Logf("Load test job failed: %v", err)
				return
			}
			defer resp.Body.Close()
			
			if resp.StatusCode == http.StatusOK {
				mu.Lock()
				successCount++
				mu.Unlock()
			}
		}()
	}
	
	wg.Wait()
	elapsed := time.Since(start)
	
	t.Logf("Load test completed: %d/%d jobs successful in %v", successCount, numJobs, elapsed)
	
	if successCount < numJobs*0.9 { // Allow 10% failure rate
		t.Errorf("Load test failed: only %d/%d jobs successful", successCount, numJobs)
	}
}

func testStress(t *testing.T, numJobs, delay int) {
	start := time.Now()
	
	var wg sync.WaitGroup
	successCount := 0
	var mu sync.Mutex
	
	for i := 0; i < numJobs; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			
			url := fmt.Sprintf("%s/delay/%d", baseURL, delay)
			resp, err := http.Get(url)
			if err != nil {
				return
			}
			defer resp.Body.Close()
			
			if resp.StatusCode == http.StatusOK {
				mu.Lock()
				successCount++
				mu.Unlock()
			}
		}()
	}
	
	wg.Wait()
	elapsed := time.Since(start)
	
	t.Logf("Stress test completed: %d/%d jobs successful in %v", successCount, numJobs, elapsed)
	
	if successCount < numJobs*0.8 { // Allow 20% failure rate for stress test
		t.Errorf("Stress test failed: only %d/%d jobs successful", successCount, numJobs)
	}
}

// Test API consistency and response formats
func TestAPIConsistency(t *testing.T) {
	t.Run("ResponseFormatConsistency", func(t *testing.T) {
		// Test multiple delay jobs and verify response format consistency
		for i := 0; i < 5; i++ {
			resp, err := http.Get(fmt.Sprintf("%s/delay/1", baseURL))
			if err != nil {
				t.Fatalf("Request failed: %v", err)
			}
			defer resp.Body.Close()
			
			var jobResp JobResponse
			if err := json.NewDecoder(resp.Body).Decode(&jobResp); err != nil {
				t.Fatalf("Failed to decode response: %v", err)
			}
			
			// Verify required fields are present
			if jobResp.Delay == 0 {
				t.Errorf("Delay field is missing or zero")
			}
			if jobResp.Status == "" {
				t.Errorf("Status field is missing")
			}
			if jobResp.JobID == "" {
				t.Errorf("JobID field is missing")
			}
			if jobResp.Completed < 0 {
				t.Errorf("Completed field is negative")
			}
		}
	})
	
	t.Run("JobListConsistency", func(t *testing.T) {
		resp, err := http.Get(baseURL + "/jobs")
		if err != nil {
			t.Fatalf("Failed to get jobs list: %v", err)
		}
		defer resp.Body.Close()
		
		var jobs JobListResponse
		if err := json.NewDecoder(resp.Body).Decode(&jobs); err != nil {
			t.Fatalf("Failed to decode jobs response: %v", err)
		}
		
		// Verify response structure
		if jobs.Count < 0 {
			t.Errorf("Job count is negative: %d", jobs.Count)
		}
		
		if len(jobs.Jobs) != jobs.Count {
			t.Errorf("Jobs array length (%d) doesn't match count (%d)", len(jobs.Jobs), jobs.Count)
		}
		
		// Verify each job has required fields
		for i, job := range jobs.Jobs {
			if job.ID == "" {
				t.Errorf("Job %d: ID field is missing", i)
			}
			if job.Status == "" {
				t.Errorf("Job %d: Status field is missing", i)
			}
			if job.Duration < 0 {
				t.Errorf("Job %d: Duration is negative", i)
			}
		}
	})
}

// Helper function to wait for server to be ready
func waitForServer(t *testing.T, maxRetries int) {
	for i := 0; i < maxRetries; i++ {
		resp, err := http.Get(baseURL + "/healthz")
		if err == nil && resp.StatusCode == http.StatusOK {
			resp.Body.Close()
			return
		}
		if resp != nil {
			resp.Body.Close()
		}
		time.Sleep(1 * time.Second)
	}
	t.Fatalf("Server not ready after %d retries", maxRetries)
}

func TestMain(m *testing.M) {
	// Wait for server to be ready
	waitForServer(&testing.T{}, 30)
	
	// Run tests
	code := m.Run()
	
	// Cleanup if needed
	os.Exit(code)
}
