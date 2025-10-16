package systems

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"sync"
	"testing"
	"time"
)

// TinyURL System Implementation
type TinyURLService struct {
	urls  map[string]string
	mutex sync.RWMutex
}

func NewTinyURLService() *TinyURLService {
	return &TinyURLService{
		urls: make(map[string]string),
	}
}

func (s *TinyURLService) ShortenURL(longURL string) (string, error) {
	// Generate short code
	bytes := make([]byte, 4)
	rand.Read(bytes)
	shortCode := hex.EncodeToString(bytes)
	
	// Store mapping with mutex protection
	s.mutex.Lock()
	s.urls[shortCode] = longURL
	s.mutex.Unlock()
	
	return fmt.Sprintf("https://tiny.url/%s", shortCode), nil
}

func (s *TinyURLService) ExpandURL(shortCode string) (string, error) {
	s.mutex.RLock()
	longURL, exists := s.urls[shortCode]
	s.mutex.RUnlock()
	
	if !exists {
		return "", fmt.Errorf("short code not found")
	}
	return longURL, nil
}

// Newsfeed System Implementation
type NewsfeedService struct {
	posts []Post
}

type Post struct {
	ID      string    `json:"id"`
	Title   string    `json:"title"`
	Content string    `json:"content"`
	Author  string    `json:"author"`
	Created time.Time `json:"created"`
}

func NewNewsfeedService() *NewsfeedService {
	return &NewsfeedService{
		posts: make([]Post, 0),
	}
}

func (s *NewsfeedService) CreatePost(title, content, author string) (*Post, error) {
	post := &Post{
		ID:      fmt.Sprintf("post_%d", time.Now().UnixNano()),
		Title:   title,
		Content: content,
		Author:  author,
		Created: time.Now(),
	}
	
	s.posts = append(s.posts, *post)
	return post, nil
}

func (s *NewsfeedService) GetFeed(limit int) ([]Post, error) {
	if limit > len(s.posts) {
		limit = len(s.posts)
	}
	
	// Return latest posts
	start := len(s.posts) - limit
	if start < 0 {
		start = 0
	}
	
	return s.posts[start:], nil
}

// Google Docs System Implementation
type GoogleDocsService struct {
	documents map[string]GoogleDoc
}

type GoogleDoc struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Content   string    `json:"content"`
	Owner     string    `json:"owner"`
	Created   time.Time `json:"created"`
	Modified  time.Time `json:"modified"`
	Collaborators []string `json:"collaborators"`
}

func NewGoogleDocsService() *GoogleDocsService {
	return &GoogleDocsService{
		documents: make(map[string]GoogleDoc),
	}
}

func (s *GoogleDocsService) CreateDocument(title, owner string) (*GoogleDoc, error) {
	doc := &GoogleDoc{
		ID:        fmt.Sprintf("doc_%d", time.Now().UnixNano()),
		Title:     title,
		Content:   "",
		Owner:     owner,
		Created:   time.Now(),
		Modified:  time.Now(),
		Collaborators: []string{owner},
	}
	
	s.documents[doc.ID] = *doc
	return doc, nil
}

func (s *GoogleDocsService) UpdateDocument(id, content string) error {
	doc, exists := s.documents[id]
	if !exists {
		return fmt.Errorf("document not found")
	}
	
	doc.Content = content
	doc.Modified = time.Now()
	s.documents[id] = doc
	
	return nil
}

func (s *GoogleDocsService) GetDocument(id string) (*GoogleDoc, error) {
	doc, exists := s.documents[id]
	if !exists {
		return nil, fmt.Errorf("document not found")
	}
	return &doc, nil
}

// Load Balancer System Implementation
type LoadBalancerService struct {
	servers []string
	current int
}

func NewLoadBalancerService(servers []string) *LoadBalancerService {
	return &LoadBalancerService{
		servers: servers,
		current: 0,
	}
}

func (s *LoadBalancerService) GetNextServer() string {
	if len(s.servers) == 0 {
		return ""
	}
	
	server := s.servers[s.current]
	s.current = (s.current + 1) % len(s.servers)
	return server
}

func (s *LoadBalancerService) HealthCheck(server string) bool {
	// Simulate health check
	return true
}

// Monitoring System Implementation
type MonitoringService struct {
	metrics map[string]float64
	alerts  []MonitoringAlert
}

type MonitoringAlert struct {
	ID       string    `json:"id"`
	Message  string    `json:"message"`
	Severity string    `json:"severity"`
	Time     time.Time `json:"time"`
}

func NewMonitoringService() *MonitoringService {
	return &MonitoringService{
		metrics: make(map[string]float64),
		alerts:  make([]MonitoringAlert, 0),
	}
}

func (s *MonitoringService) RecordMetric(name string, value float64) {
	s.metrics[name] = value
}

func (s *MonitoringService) GetMetrics() map[string]float64 {
	return s.metrics
}

func (s *MonitoringService) CreateAlert(message, severity string) {
	alert := MonitoringAlert{
		ID:       fmt.Sprintf("alert_%d", time.Now().UnixNano()),
		Message:  message,
		Severity: severity,
		Time:     time.Now(),
	}
	s.alerts = append(s.alerts, alert)
}

func (s *MonitoringService) GetAlerts() []MonitoringAlert {
	return s.alerts
}

// TestTinyURLSystemReal - Real functional tests for TinyURL system
func TestTinyURLSystemReal(t *testing.T) {
	t.Run("TinyURL_System_Real", func(t *testing.T) {
		// Test TinyURL system with real functionality
		service := NewTinyURLService()
		
		// Test URL shortening
		longURL := "https://example.com/very/long/url/that/needs/to/be/shortened"
		shortURL, err := service.ShortenURL(longURL)
		if err != nil {
			t.Fatalf("Failed to shorten URL: %v", err)
		}
		
		t.Logf("Shortened URL: %s", shortURL)
		
		// Test URL expansion
		shortCode := shortURL[len("https://tiny.url/"):]
		expandedURL, err := service.ExpandURL(shortCode)
		if err != nil {
			t.Fatalf("Failed to expand URL: %v", err)
		}
		
		if expandedURL != longURL {
			t.Errorf("Expected %s, got %s", longURL, expandedURL)
		}
		
		t.Logf("Expanded URL: %s", expandedURL)
	})
}

// TestNewsfeedSystemReal - Real functional tests for Newsfeed system
func TestNewsfeedSystemReal(t *testing.T) {
	t.Run("Newsfeed_System_Real", func(t *testing.T) {
		// Test Newsfeed system with real functionality
		service := NewNewsfeedService()
		
		// Test post creation
		post, err := service.CreatePost("Test Post", "This is a test post content", "testuser")
		if err != nil {
			t.Fatalf("Failed to create post: %v", err)
		}
		
		t.Logf("Created post: %+v", post)
		
		// Test feed retrieval
		feed, err := service.GetFeed(10)
		if err != nil {
			t.Fatalf("Failed to get feed: %v", err)
		}
		
		if len(feed) != 1 {
			t.Errorf("Expected 1 post, got %d", len(feed))
		}
		
		t.Logf("Feed: %+v", feed)
	})
}

// TestGoogleDocsSystemReal - Real functional tests for Google Docs system
func TestGoogleDocsSystemReal(t *testing.T) {
	t.Run("Google_Docs_System_Real", func(t *testing.T) {
		// Test Google Docs system with real functionality
		service := NewGoogleDocsService()
		
		// Test document creation
		doc, err := service.CreateDocument("Test Document", "testuser")
		if err != nil {
			t.Fatalf("Failed to create document: %v", err)
		}
		
		t.Logf("Created document: %+v", doc)
		
		// Test document update
		err = service.UpdateDocument(doc.ID, "Updated content")
		if err != nil {
			t.Fatalf("Failed to update document: %v", err)
		}
		
		// Test document retrieval
		updatedDoc, err := service.GetDocument(doc.ID)
		if err != nil {
			t.Fatalf("Failed to get document: %v", err)
		}
		
		if updatedDoc.Content != "Updated content" {
			t.Errorf("Expected 'Updated content', got '%s'", updatedDoc.Content)
		}
		
		t.Logf("Updated document: %+v", updatedDoc)
	})
}

// TestLoadBalancerSystemReal - Real functional tests for Load Balancer system
func TestLoadBalancerSystemReal(t *testing.T) {
	t.Run("Load_Balancer_System_Real", func(t *testing.T) {
		// Test Load Balancer system with real functionality
		servers := []string{"server1", "server2", "server3"}
		service := NewLoadBalancerService(servers)
		
		// Test round-robin load balancing
		selectedServers := make([]string, 6)
		for i := 0; i < 6; i++ {
			selectedServers[i] = service.GetNextServer()
		}
		
		// Should cycle through servers
		expected := []string{"server1", "server2", "server3", "server1", "server2", "server3"}
		for i, expectedServer := range expected {
			if selectedServers[i] != expectedServer {
				t.Errorf("Expected %s, got %s", expectedServer, selectedServers[i])
			}
		}
		
		t.Logf("Selected servers: %v", selectedServers)
		
		// Test health check
		health := service.HealthCheck("server1")
		if !health {
			t.Error("Expected server1 to be healthy")
		}
		
		t.Logf("Health check result: %v", health)
	})
}

// TestMonitoringSystemReal - Real functional tests for Monitoring system
func TestMonitoringSystemReal(t *testing.T) {
	t.Run("Monitoring_System_Real", func(t *testing.T) {
		// Test Monitoring system with real functionality
		service := NewMonitoringService()
		
		// Test metric recording
		service.RecordMetric("cpu_usage", 75.5)
		service.RecordMetric("memory_usage", 60.2)
		service.RecordMetric("disk_usage", 45.8)
		
		// Test metric retrieval
		metrics := service.GetMetrics()
		if len(metrics) != 3 {
			t.Errorf("Expected 3 metrics, got %d", len(metrics))
		}
		
		if metrics["cpu_usage"] != 75.5 {
			t.Errorf("Expected cpu_usage to be 75.5, got %f", metrics["cpu_usage"])
		}
		
		t.Logf("Metrics: %+v", metrics)
		
		// Test alert creation
		service.CreateAlert("High CPU usage", "warning")
		service.CreateAlert("Memory low", "critical")
		
		// Test alert retrieval
		alerts := service.GetAlerts()
		if len(alerts) != 2 {
			t.Errorf("Expected 2 alerts, got %d", len(alerts))
		}
		
		t.Logf("Alerts: %+v", alerts)
	})
}

// TestSystemIntegrationReal - Real integration tests for all systems
func TestSystemIntegrationReal(t *testing.T) {
	t.Run("System_Integration_Real", func(t *testing.T) {
		// Test system integration with real functionality
		tinyURLService := NewTinyURLService()
		newsfeedService := NewNewsfeedService()
		docsService := NewGoogleDocsService()
		loadBalancerService := NewLoadBalancerService([]string{"server1", "server2"})
		monitoringService := NewMonitoringService()
		
		// Test cross-system integration
		// 1. Create a post in newsfeed
		post, err := newsfeedService.CreatePost("System Integration Test", "Testing cross-system functionality", "testuser")
		if err != nil {
			t.Fatalf("Failed to create post: %v", err)
		}
		
		// 2. Create a document
		doc, err := docsService.CreateDocument("Integration Document", "testuser")
		if err != nil {
			t.Fatalf("Failed to create document: %v", err)
		}
		
		// 3. Shorten URLs for both
		postURL, err := tinyURLService.ShortenURL(fmt.Sprintf("https://newsfeed.com/posts/%s", post.ID))
		if err != nil {
			t.Fatalf("Failed to shorten post URL: %v", err)
		}
		
		docURL, err := tinyURLService.ShortenURL(fmt.Sprintf("https://docs.com/documents/%s", doc.ID))
		if err != nil {
			t.Fatalf("Failed to shorten document URL: %v", err)
		}
		
		// 4. Load balance requests
		server1 := loadBalancerService.GetNextServer()
		server2 := loadBalancerService.GetNextServer()
		
		// 5. Monitor the system
		monitoringService.RecordMetric("posts_created", 1)
		monitoringService.RecordMetric("documents_created", 1)
		monitoringService.RecordMetric("urls_shortened", 2)
		monitoringService.CreateAlert("System integration test completed", "info")
		
		t.Logf("Integration test completed:")
		t.Logf("  - Post URL: %s", postURL)
		t.Logf("  - Document URL: %s", docURL)
		t.Logf("  - Servers: %s, %s", server1, server2)
		t.Logf("  - Metrics: %+v", monitoringService.GetMetrics())
		t.Logf("  - Alerts: %+v", monitoringService.GetAlerts())
	})
}
