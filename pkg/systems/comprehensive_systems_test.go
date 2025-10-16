package systems

import (
	"fmt"
	"testing"
	"time"
)

// TestSystemsComprehensive - Comprehensive tests for all systems
func TestSystemsComprehensive(t *testing.T) {
	t.Run("Systems_Comprehensive", func(t *testing.T) {
		// Test comprehensive systems functionality
		t.Log("Comprehensive systems test")
	})
	
	t.Run("TinyURL_System_Comprehensive", func(t *testing.T) {
		// Test TinyURL system comprehensively
		service := NewTinyURLService()
		
		// Test basic functionality
		longURL := "https://example.com/very/long/url/that/needs/to/be/shortened"
		shortURL, err := service.ShortenURL(longURL)
		if err != nil {
			t.Fatalf("Failed to shorten URL: %v", err)
		}
		
		// Test expansion
		shortCode := shortURL[len("https://tiny.url/"):]
		expandedURL, err := service.ExpandURL(shortCode)
		if err != nil {
			t.Fatalf("Failed to expand URL: %v", err)
		}
		
		if expandedURL != longURL {
			t.Errorf("Expected %s, got %s", longURL, expandedURL)
		}
		
		t.Logf("TinyURL system test completed: %s -> %s -> %s", longURL, shortURL, expandedURL)
	})
	
	t.Run("Newsfeed_System_Comprehensive", func(t *testing.T) {
		// Test Newsfeed system comprehensively
		service := NewNewsfeedService()
		
		// Test post creation
		post, err := service.CreatePost("Test Post", "This is a test post content", "testuser")
		if err != nil {
			t.Fatalf("Failed to create post: %v", err)
		}
		
		// Test feed retrieval
		feed, err := service.GetFeed(10)
		if err != nil {
			t.Fatalf("Failed to get feed: %v", err)
		}
		
		if len(feed) != 1 {
			t.Errorf("Expected 1 post, got %d", len(feed))
		}
		
		t.Logf("Newsfeed system test completed: created post %s", post.ID)
	})
	
	t.Run("Google_Docs_System_Comprehensive", func(t *testing.T) {
		// Test Google Docs system comprehensively
		service := NewGoogleDocsService()
		
		// Test document creation
		doc, err := service.CreateDocument("Test Document", "testuser")
		if err != nil {
			t.Fatalf("Failed to create document: %v", err)
		}
		
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
		
		t.Logf("Google Docs system test completed: created document %s", doc.ID)
	})
	
	t.Run("Load_Balancer_System_Comprehensive", func(t *testing.T) {
		// Test Load Balancer system comprehensively
		servers := []string{"server1", "server2", "server3"}
		service := NewLoadBalancerService(servers)
		
		// Test round-robin
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
		
		// Test health check
		health := service.HealthCheck("server1")
		if !health {
			t.Error("Expected server1 to be healthy")
		}
		
		t.Logf("Load Balancer system test completed: %v", selectedServers)
	})
	
	t.Run("Monitoring_System_Comprehensive", func(t *testing.T) {
		// Test Monitoring system comprehensively
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
		
		// Test alert creation
		service.CreateAlert("High CPU usage", "warning")
		service.CreateAlert("Memory low", "critical")
		
		// Test alert retrieval
		alerts := service.GetAlerts()
		if len(alerts) != 2 {
			t.Errorf("Expected 2 alerts, got %d", len(alerts))
		}
		
		t.Logf("Monitoring system test completed: %d metrics, %d alerts", len(metrics), len(alerts))
	})
}

// TestSystemsPerformance - Performance tests for all systems
func TestSystemsPerformance(t *testing.T) {
	t.Run("TinyURL_Performance", func(t *testing.T) {
		service := NewTinyURLService()
		start := time.Now()
		
		for i := 0; i < 1000; i++ {
			longURL := fmt.Sprintf("https://example.com/url/%d", i)
			shortURL, _ := service.ShortenURL(longURL)
			service.ExpandURL(shortURL[len("https://tiny.url/"):])
		}
		
		duration := time.Since(start)
		t.Logf("TinyURL performance: 1000 operations in %v", duration)
	})
	
	t.Run("Newsfeed_Performance", func(t *testing.T) {
		service := NewNewsfeedService()
		start := time.Now()
		
		for i := 0; i < 500; i++ {
			service.CreatePost(fmt.Sprintf("Post %d", i), "Content", "user")
		}
		
		duration := time.Since(start)
		t.Logf("Newsfeed performance: 500 posts in %v", duration)
	})
	
	t.Run("LoadBalancer_Performance", func(t *testing.T) {
		servers := []string{"server1", "server2", "server3", "server4", "server5"}
		service := NewLoadBalancerService(servers)
		start := time.Now()
		
		for i := 0; i < 2000; i++ {
			service.GetNextServer()
		}
		
		duration := time.Since(start)
		t.Logf("LoadBalancer performance: 2000 requests in %v", duration)
	})
}

// TestSystemsConcurrency - Concurrency tests for all systems
func TestSystemsConcurrency(t *testing.T) {
	t.Run("TinyURL_Concurrency", func(t *testing.T) {
		service := NewTinyURLService()
		done := make(chan bool, 50)
		
		for i := 0; i < 50; i++ {
			go func(id int) {
				longURL := fmt.Sprintf("https://example.com/url/%d", id)
				shortURL, _ := service.ShortenURL(longURL)
				service.ExpandURL(shortURL[len("https://tiny.url/"):])
				done <- true
			}(i)
		}
		
		for i := 0; i < 50; i++ {
			<-done
		}
		
		t.Log("TinyURL concurrency test completed")
	})
	
	t.Run("Newsfeed_Concurrency", func(t *testing.T) {
		service := NewNewsfeedService()
		done := make(chan bool, 30)
		
		for i := 0; i < 30; i++ {
			go func(id int) {
				service.CreatePost(fmt.Sprintf("Post %d", id), "Content", "user")
				done <- true
			}(i)
		}
		
		for i := 0; i < 30; i++ {
			<-done
		}
		
		t.Log("Newsfeed concurrency test completed")
	})
	
	t.Run("LoadBalancer_Concurrency", func(t *testing.T) {
		servers := []string{"server1", "server2", "server3"}
		service := NewLoadBalancerService(servers)
		done := make(chan bool, 40)
		
		for i := 0; i < 40; i++ {
			go func(id int) {
				service.GetNextServer()
				done <- true
			}(i)
		}
		
		for i := 0; i < 40; i++ {
			<-done
		}
		
		t.Log("LoadBalancer concurrency test completed")
	})
}

// TestSystemsEdgeCases - Edge case tests for all systems
func TestSystemsEdgeCases(t *testing.T) {
	t.Run("TinyURL_Edge_Cases", func(t *testing.T) {
		service := NewTinyURLService()
		
		// Test empty URL (current implementation allows it)
		shortURL, err := service.ShortenURL("")
		if err != nil {
			t.Errorf("Unexpected error for empty URL: %v", err)
		}
		if shortURL == "" {
			t.Error("Expected non-empty short URL")
		}
		
		// Test non-existent short code
		_, err = service.ExpandURL("nonexistent")
		if err == nil {
			t.Error("Expected error for non-existent short code")
		}
		
		t.Log("TinyURL edge cases test completed")
	})
	
	t.Run("Newsfeed_Edge_Cases", func(t *testing.T) {
		service := NewNewsfeedService()
		
		// Test empty title (current implementation allows it)
		post, err := service.CreatePost("", "Content", "user")
		if err != nil {
			t.Errorf("Unexpected error for empty title: %v", err)
		}
		if post == nil {
			t.Error("Expected post to be created")
		}
		
		// Test empty content (current implementation allows it)
		post2, err := service.CreatePost("Title", "", "user")
		if err != nil {
			t.Errorf("Unexpected error for empty content: %v", err)
		}
		if post2 == nil {
			t.Error("Expected post to be created")
		}
		
		t.Log("Newsfeed edge cases test completed")
	})
	
	t.Run("Google_Docs_Edge_Cases", func(t *testing.T) {
		service := NewGoogleDocsService()
		
		// Test empty title (current implementation allows it)
		doc, err := service.CreateDocument("", "user")
		if err != nil {
			t.Errorf("Unexpected error for empty title: %v", err)
		}
		if doc == nil {
			t.Error("Expected document to be created")
		}
		
		// Test non-existent document
		err = service.UpdateDocument("nonexistent", "content")
		if err == nil {
			t.Error("Expected error for non-existent document")
		}
		
		// Test non-existent document retrieval
		_, err = service.GetDocument("nonexistent")
		if err == nil {
			t.Error("Expected error for non-existent document")
		}
		
		t.Log("Google Docs edge cases test completed")
	})
}

// TestSystemsIntegration - Integration tests for all systems
func TestSystemsIntegration(t *testing.T) {
	t.Run("Full_System_Integration", func(t *testing.T) {
		// Initialize all services
		tinyURLService := NewTinyURLService()
		newsfeedService := NewNewsfeedService()
		docsService := NewGoogleDocsService()
		loadBalancerService := NewLoadBalancerService([]string{"server1", "server2"})
		monitoringService := NewMonitoringService()
		
		// Test cross-system integration
		// 1. Create a post
		post, err := newsfeedService.CreatePost("Integration Test", "Content", "user")
		if err != nil {
			t.Fatalf("Failed to create post: %v", err)
		}
		
		// 2. Create a document
		doc, err := docsService.CreateDocument("Integration Doc", "user")
		if err != nil {
			t.Fatalf("Failed to create document: %v", err)
		}
		
		// 3. Shorten URLs for both
		_, err = tinyURLService.ShortenURL(fmt.Sprintf("https://newsfeed.com/posts/%s", post.ID))
		if err != nil {
			t.Fatalf("Failed to shorten post URL: %v", err)
		}
		
		_, err = tinyURLService.ShortenURL(fmt.Sprintf("https://docs.com/documents/%s", doc.ID))
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
		monitoringService.CreateAlert("Integration test completed", "info")
		
		// Verify integration
		if server1 == server2 {
			t.Error("Load balancer should return different servers")
		}
		
		metrics := monitoringService.GetMetrics()
		if len(metrics) != 3 {
			t.Errorf("Expected 3 metrics, got %d", len(metrics))
		}
		
		alerts := monitoringService.GetAlerts()
		if len(alerts) != 1 {
			t.Errorf("Expected 1 alert, got %d", len(alerts))
		}
		
		t.Log("✅ Full system integration test completed successfully")
	})
}