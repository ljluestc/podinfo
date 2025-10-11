package http

import (
	"context"
	"fmt"
	"math/rand"
	"net/http"
	"sync"
	"strconv"
	"time"

	"github.com/gorilla/mux"
)

type RandomDelayMiddleware struct {
	min  int
	max  int
	unit string
}

// Job represents a long-running operation that can be cancelled
type Job struct {
	ID        string
	Status    string // "running", "cancelled", "completed"
	StartTime time.Time
	Cancel    context.CancelFunc
}

// JobManager manages active jobs and their cancellation
type JobManager struct {
	jobs map[string]*Job
	mux  sync.RWMutex
}

var jobManager = &JobManager{
	jobs: make(map[string]*Job),
}

// AddJob adds a new job to the manager
func (jm *JobManager) AddJob(job *Job) {
	jm.mux.Lock()
	defer jm.mux.Unlock()
	jm.jobs[job.ID] = job
}

// GetJob retrieves a job by ID
func (jm *JobManager) GetJob(id string) (*Job, bool) {
	jm.mux.RLock()
	defer jm.mux.RUnlock()
	job, exists := jm.jobs[id]
	return job, exists
}

// CancelJob cancels a job by ID
func (jm *JobManager) CancelJob(id string) bool {
	jm.mux.Lock()
	defer jm.mux.Unlock()
	job, exists := jm.jobs[id]
	if exists && job.Status == "running" {
		job.Status = "cancelled"
		job.Cancel()
		return true
	}
	return false
}

// RemoveJob removes a completed job
func (jm *JobManager) RemoveJob(id string) {
	jm.mux.Lock()
	defer jm.mux.Unlock()
	delete(jm.jobs, id)
}

// GetAllJobs returns all active jobs
func (jm *JobManager) GetAllJobs() map[string]*Job {
	jm.mux.RLock()
	defer jm.mux.RUnlock()
	jobs := make(map[string]*Job)
	for k, v := range jm.jobs {
		jobs[k] = v
	}
	return jobs
}

func NewRandomDelayMiddleware(minDelay, maxDelay int, delayUnit string) *RandomDelayMiddleware {
	return &RandomDelayMiddleware{
		min:  minDelay,
		max:  maxDelay,
		unit: delayUnit,
	}
}

func (m *RandomDelayMiddleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var unit time.Duration
		rand.Seed(time.Now().Unix())
		switch m.unit {
		case "s":
			unit = time.Second
		case "ms":
			unit = time.Millisecond
		default:
			unit = time.Second
		}

		delay := rand.Intn(m.max-m.min) + m.min
		time.Sleep(time.Duration(delay) * unit)
		next.ServeHTTP(w, r)
	})
}

// Delay godoc
// @Summary Delay
// @Description waits for the specified period
// @Tags HTTP API
// @Accept json
// @Produce json
// @Param seconds path int true "seconds to wait for"
// @Router /delay/{seconds} [get]
// @Success 200 {object} http.MapResponse
func (s *Server) delayHandler(w http.ResponseWriter, r *http.Request) {
	_, span := s.tracer.Start(r.Context(), "delayHandler")
	defer span.End()

	vars := mux.Vars(r)

	delay, err := strconv.Atoi(vars["wait"])
	if err != nil {
		s.ErrorResponse(w, r, span, err.Error(), http.StatusBadRequest)
		return
	}

	// Create a cancellable context
	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()

	// Generate a unique job ID
	jobID := generateJobID()
	job := &Job{
		ID:        jobID,
		Status:    "running",
		StartTime: time.Now(),
		Cancel:    cancel,
	}

	// Add job to manager
	jobManager.AddJob(job)
	defer jobManager.RemoveJob(jobID)

	// Use a ticker to check for cancellation periodically
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	remainingDelay := time.Duration(delay) * time.Second
	startTime := time.Now()

	for remainingDelay > 0 {
		select {
		case <-ctx.Done():
			// Job was cancelled
			job.Status = "cancelled"
			s.JSONResponse(w, r, map[string]interface{}{
				"delay":     delay,
				"status":    "cancelled",
				"job_id":    jobID,
				"completed": time.Since(startTime).Seconds(),
			})
			return
		case <-ticker.C:
			// Check if job was cancelled externally
			if job.Status == "cancelled" {
				s.JSONResponse(w, r, map[string]interface{}{
					"delay":     delay,
					"status":    "cancelled",
					"job_id":    jobID,
					"completed": time.Since(startTime).Seconds(),
				})
				return
			}
			// Continue with a small delay
			time.Sleep(100 * time.Millisecond)
			remainingDelay -= 100 * time.Millisecond
		}
	}

	// Job completed successfully
	job.Status = "completed"
	s.JSONResponse(w, r, map[string]interface{}{
		"delay":     delay,
		"status":    "completed",
		"job_id":    jobID,
		"completed": time.Since(startTime).Seconds(),
	})
}

// generateJobID creates a unique job identifier
func generateJobID() string {
	return fmt.Sprintf("job_%d_%d", time.Now().Unix(), rand.Intn(10000))
}

// CancelJob godoc
// @Summary Cancel Job
// @Description cancels a running job by ID
// @Tags HTTP API
// @Accept json
// @Produce json
// @Param id path string true "job ID to cancel"
// @Router /jobs/{id}/cancel [post]
// @Success 200 {object} http.MapResponse
func (s *Server) cancelJobHandler(w http.ResponseWriter, r *http.Request) {
	_, span := s.tracer.Start(r.Context(), "cancelJobHandler")
	defer span.End()

	vars := mux.Vars(r)
	jobID := vars["id"]

	success := jobManager.CancelJob(jobID)
	if success {
		s.JSONResponse(w, r, map[string]interface{}{
			"status": "cancelled",
			"job_id": jobID,
		})
	} else {
		s.ErrorResponse(w, r, span, "Job not found or already completed", http.StatusNotFound)
	}
}

// ListJobs godoc
// @Summary List Jobs
// @Description lists all active jobs
// @Tags HTTP API
// @Accept json
// @Produce json
// @Router /jobs [get]
// @Success 200 {object} http.MapResponse
func (s *Server) listJobsHandler(w http.ResponseWriter, r *http.Request) {
	_, span := s.tracer.Start(r.Context(), "listJobsHandler")
	defer span.End()

	jobs := jobManager.GetAllJobs()
	jobList := make([]map[string]interface{}, 0, len(jobs))
	
	for _, job := range jobs {
		jobList = append(jobList, map[string]interface{}{
			"id":         job.ID,
			"status":     job.Status,
			"start_time": job.StartTime,
			"duration":   time.Since(job.StartTime).Seconds(),
		})
	}

	s.JSONResponse(w, r, map[string]interface{}{
		"jobs":  jobList,
		"count": len(jobList),
	})
}

// GetJob godoc
// @Summary Get Job
// @Description gets job details by ID
// @Tags HTTP API
// @Accept json
// @Produce json
// @Param id path string true "job ID"
// @Router /jobs/{id} [get]
// @Success 200 {object} http.MapResponse
func (s *Server) getJobHandler(w http.ResponseWriter, r *http.Request) {
	_, span := s.tracer.Start(r.Context(), "getJobHandler")
	defer span.End()

	vars := mux.Vars(r)
	jobID := vars["id"]

	job, exists := jobManager.GetJob(jobID)
	if !exists {
		s.ErrorResponse(w, r, span, "Job not found", http.StatusNotFound)
		return
	}

	s.JSONResponse(w, r, map[string]interface{}{
		"id":         job.ID,
		"status":     job.Status,
		"start_time": job.StartTime,
		"duration":   time.Since(job.StartTime).Seconds(),
	})
}
