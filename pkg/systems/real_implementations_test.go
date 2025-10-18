package systems

import (
	"fmt"
	"testing"
)

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
