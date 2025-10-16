package test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
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

func TestDelayJobCompletion(t *testing.T) {
	// Test that a delay job completes successfully
	delay := 2
	url := fmt.Sprintf("%s/delay/%d", baseURL, delay)
	
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
	
	if jobResp.Delay != delay {
		t.Errorf("Expected delay %d, got %d", delay, jobResp.Delay)
	}
	
	// Verify it took approximately the right amount of time
	if elapsed < time.Duration(delay)*time.Second || elapsed > time.Duration(delay+1)*time.Second {
		t.Errorf("Expected delay around %ds, took %v", delay, elapsed)
	}
	
	t.Logf("Job completed successfully: %+v", jobResp)
}

func TestDelayJobCancellation(t *testing.T) {
	// Test that a delay job can be cancelled
	delay := 10 // Long delay to ensure we have time to cancel
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
	jobsResp, err := http.Get(fmt.Sprintf("%s/jobs", baseURL))
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

func TestJobStatusEndpoint(t *testing.T) {
	// Test job status and list endpoints
	delay := 3
	url := fmt.Sprintf("%s/delay/%d", baseURL, delay)
	
	// Start a job
	go func() {
		http.Get(url)
	}()
	
	// Wait for job to start
	time.Sleep(500 * time.Millisecond)
	
	// Test list jobs endpoint
	jobsResp, err := http.Get(fmt.Sprintf("%s/jobs", baseURL))
	if err != nil {
		t.Fatalf("Failed to get jobs list: %v", err)
	}
	defer jobsResp.Body.Close()
	
	if jobsResp.StatusCode != http.StatusOK {
		t.Fatalf("Expected status 200, got %d", jobsResp.StatusCode)
	}
	
	var jobs JobListResponse
	if err := json.NewDecoder(jobsResp.Body).Decode(&jobs); err != nil {
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
}

func TestCancelNonExistentJob(t *testing.T) {
	// Test cancelling a non-existent job
	fakeJobID := "fake-job-id"
	cancelURL := fmt.Sprintf("%s/jobs/%s/cancel", baseURL, fakeJobID)
	
	resp, err := http.Post(cancelURL, "application/json", nil)
	if err != nil {
		t.Fatalf("Failed to attempt cancel: %v", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Expected status 404 for non-existent job, got %d", resp.StatusCode)
	}
}

func TestConcurrentJobs(t *testing.T) {
	// Test multiple concurrent jobs
	numJobs := 3
	delay := 2
	
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
	timeout := time.After(10 * time.Second)
	
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

func TestJobCancellationRaceCondition(t *testing.T) {
	// Test race condition between job completion and cancellation
	delay := 1 // Short delay
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
	jobsResp, err := http.Get(fmt.Sprintf("%s/jobs", baseURL))
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
		// Job completed (either normally or was cancelled)
		t.Logf("Job completed with status: %s", jobResp.Status)
	case err := <-errChan:
		t.Fatalf("Job failed: %v", err)
	case <-time.After(5 * time.Second):
		t.Fatalf("Job did not complete within timeout")
	}
}

// Helper function to wait for server to be ready
func waitForServer(t *testing.T, maxRetries int) {
	for i := 0; i < maxRetries; i++ {
		resp, err := http.Get(fmt.Sprintf("%s/healthz", baseURL))
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
