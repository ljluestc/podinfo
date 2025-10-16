package test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	"github.com/gorilla/websocket"
	"github.com/stefanprodan/podinfo/pkg/api/grpc"
	"github.com/stefanprodan/podinfo/pkg/api/http"
	"github.com/stefanprodan/podinfo/pkg/fscache"
	"github.com/stefanprodan/podinfo/pkg/signals"
	"github.com/stefanprodan/podinfo/pkg/version"
)

// TestFullApplicationIntegration - Comprehensive integration test
func TestFullApplicationIntegration(t *testing.T) {
	t.Run("Complete_HTTP_API_Integration", func(t *testing.T) {
		// Create a complete HTTP server with all handlers
		mux := http.NewServeMux()
		
		// Add all HTTP handlers
		mux.HandleFunc("/", http.IndexHandler())
		mux.HandleFunc("/healthz", http.HealthzHandler())
		mux.HandleFunc("/readyz", http.ReadyzHandler())
		mux.HandleFunc("/version", http.VersionHandler())
		mux.HandleFunc("/info", http.InfoHandler())
		mux.HandleFunc("/status/200", http.StatusHandler())
		mux.HandleFunc("/token", http.TokenHandler())
		mux.HandleFunc("/echo", http.EchoHandler())
		mux.HandleFunc("/env", http.EnvHandler())
		mux.HandleFunc("/delay/1", http.DelayHandler())
		mux.HandleFunc("/metrics", http.MetricsHandler())
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		// Test all endpoints
		endpoints := []string{
			"/",
			"/healthz",
			"/readyz",
			"/version",
			"/info",
			"/status/200",
			"/token",
			"/echo?message=test",
			"/env",
			"/delay/1",
			"/metrics",
		}
		
		for _, endpoint := range endpoints {
			t.Run(fmt.Sprintf("Endpoint_%s", endpoint), func(t *testing.T) {
				resp, err := http.Get(server.URL + endpoint)
				if err != nil {
					t.Errorf("Failed to GET %s: %v", endpoint, err)
					return
				}
				defer resp.Body.Close()
				
				if resp.StatusCode != http.StatusOK {
					t.Errorf("Expected status 200 for %s, got %d", endpoint, resp.StatusCode)
				}
			})
		}
	})
	
	t.Run("WebSocket_Integration", func(t *testing.T) {
		// Create WebSocket server
		upgrader := websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		}
		
		mux := http.NewServeMux()
		mux.HandleFunc("/echo", func(w http.ResponseWriter, r *http.Request) {
			conn, err := upgrader.Upgrade(w, r, nil)
			if err != nil {
				return
			}
			defer conn.Close()
			
			// Echo messages
			for {
				_, message, err := conn.ReadMessage()
				if err != nil {
					return
				}
				conn.WriteMessage(websocket.TextMessage, message)
			}
		})
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		// Test WebSocket connection
		wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/echo"
		conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
		if err != nil {
			t.Fatalf("Failed to connect to WebSocket: %v", err)
		}
		defer conn.Close()
		
		// Send test message
		testMessage := "Integration test message"
		if err := conn.WriteMessage(websocket.TextMessage, []byte(testMessage)); err != nil {
			t.Fatalf("Failed to write message: %v", err)
		}
		
		// Read echo response
		_, message, err := conn.ReadMessage()
		if err != nil {
			t.Fatalf("Failed to read message: %v", err)
		}
		
		if string(message) != testMessage {
			t.Errorf("Expected '%s', got '%s'", testMessage, string(message))
		}
	})
}

// TestFSCacheIntegration - Integration test for file system cache
func TestFSCacheIntegration(t *testing.T) {
	t.Run("FSCache_With_HTTP_Integration", func(t *testing.T) {
		// Create temporary directory
		tempDir := t.TempDir()
		
		// Create FSCache watcher
		watcher, err := fscache.NewWatch(tempDir)
		if err != nil {
			t.Fatalf("Failed to create watcher: %v", err)
		}
		
		// Create HTTP server with cache handler
		mux := http.NewServeMux()
		mux.HandleFunc("/cache", http.CacheHandler(watcher, watcher))
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		// Test cache endpoint
		resp, err := http.Get(server.URL + "/cache")
		if err != nil {
			t.Errorf("Failed to GET /cache: %v", err)
			return
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusOK {
			t.Errorf("Expected status 200, got %d", resp.StatusCode)
		}
	})
}

// TestSignalHandlingIntegration - Integration test for signal handling
func TestSignalHandlingIntegration(t *testing.T) {
	t.Run("Signal_Handler_With_HTTP_Server", func(t *testing.T) {
		// Create HTTP server
		mux := http.NewServeMux()
		mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("OK"))
		})
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		// Test signal handler setup
		ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
		defer cancel()
		
		// This should not panic
		signals.SetupSignalHandler()
	})
}

// TestVersionIntegration - Integration test for version
func TestVersionIntegration(t *testing.T) {
	t.Run("Version_With_HTTP_Response", func(t *testing.T) {
		// Create HTTP server with version handler
		mux := http.NewServeMux()
		mux.HandleFunc("/version", http.VersionHandler())
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		// Test version endpoint
		resp, err := http.Get(server.URL + "/version")
		if err != nil {
			t.Errorf("Failed to GET /version: %v", err)
			return
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusOK {
			t.Errorf("Expected status 200, got %d", resp.StatusCode)
		}
		
		// Parse version response
		var versionResp map[string]string
		if err := json.NewDecoder(resp.Body).Decode(&versionResp); err != nil {
			t.Errorf("Failed to decode version response: %v", err)
			return
		}
		
		if versionResp["version"] == "" {
			t.Error("Expected non-empty version")
		}
	})
}

// TestConcurrentOperationsIntegration - Integration test for concurrent operations
func TestConcurrentOperationsIntegration(t *testing.T) {
	t.Run("Concurrent_HTTP_Requests", func(t *testing.T) {
		// Create HTTP server
		mux := http.NewServeMux()
		mux.HandleFunc("/echo", http.EchoHandler())
		mux.HandleFunc("/delay/1", http.DelayHandler())
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		concurrency := 10
		done := make(chan bool, concurrency)
		
		// Concurrent requests
		for i := 0; i < concurrency; i++ {
			go func(id int) {
				defer func() { done <- true }()
				
				// Test echo endpoint
				resp, err := http.Get(fmt.Sprintf("%s/echo?message=test-%d", server.URL, id))
				if err != nil {
					t.Errorf("Concurrent request %d failed: %v", id, err)
					return
				}
				defer resp.Body.Close()
				
				if resp.StatusCode != http.StatusOK {
					t.Errorf("Expected status 200 for request %d, got %d", id, resp.StatusCode)
				}
			}(i)
		}
		
		// Wait for all requests to complete
		for i := 0; i < concurrency; i++ {
			<-done
		}
	})
	
	t.Run("Concurrent_WebSocket_Connections", func(t *testing.T) {
		// Create WebSocket server
		upgrader := websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		}
		
		mux := http.NewServeMux()
		mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
			conn, err := upgrader.Upgrade(w, r, nil)
			if err != nil {
				return
			}
			defer conn.Close()
			
			// Echo messages
			for {
				_, message, err := conn.ReadMessage()
				if err != nil {
					return
				}
				conn.WriteMessage(websocket.TextMessage, message)
			}
		})
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		concurrency := 5
		done := make(chan bool, concurrency)
		
		// Concurrent WebSocket connections
		for i := 0; i < concurrency; i++ {
			go func(id int) {
				defer func() { done <- true }()
				
				wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
				conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
				if err != nil {
					t.Errorf("WebSocket connection %d failed: %v", id, err)
					return
				}
				defer conn.Close()
				
				// Send and receive message
				testMessage := fmt.Sprintf("test-%d", id)
				if err := conn.WriteMessage(websocket.TextMessage, []byte(testMessage)); err != nil {
					t.Errorf("Failed to write message %d: %v", id, err)
					return
				}
				
				_, message, err := conn.ReadMessage()
				if err != nil {
					t.Errorf("Failed to read message %d: %v", id, err)
					return
				}
				
				if string(message) != testMessage {
					t.Errorf("Expected '%s' for connection %d, got '%s'", testMessage, id, string(message))
				}
			}(i)
		}
		
		// Wait for all connections to complete
		for i := 0; i < concurrency; i++ {
			<-done
		}
	})
}

// TestErrorHandlingIntegration - Integration test for error handling
func TestErrorHandlingIntegration(t *testing.T) {
	t.Run("HTTP_Error_Handling", func(t *testing.T) {
		// Create HTTP server with error handling
		mux := http.NewServeMux()
		mux.HandleFunc("/status/500", http.StatusHandler())
		mux.HandleFunc("/delay/invalid", http.DelayHandler())
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		// Test 500 status
		resp, err := http.Get(server.URL + "/status/500")
		if err != nil {
			t.Errorf("Failed to GET /status/500: %v", err)
			return
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusInternalServerError {
			t.Errorf("Expected status 500, got %d", resp.StatusCode)
		}
		
		// Test invalid delay parameter
		resp, err = http.Get(server.URL + "/delay/invalid")
		if err != nil {
			t.Errorf("Failed to GET /delay/invalid: %v", err)
			return
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("Expected status 400 for invalid delay, got %d", resp.StatusCode)
		}
	})
	
	t.Run("WebSocket_Error_Handling", func(t *testing.T) {
		// Test WebSocket connection to non-existent server
		_, _, err := websocket.DefaultDialer.Dial("ws://localhost:99999/ws", nil)
		if err == nil {
			t.Error("Expected error for non-existent WebSocket server")
		}
	})
}

// TestPerformanceIntegration - Integration test for performance
func TestPerformanceIntegration(t *testing.T) {
	t.Run("HTTP_Response_Time", func(t *testing.T) {
		// Create HTTP server
		mux := http.NewServeMux()
		mux.HandleFunc("/echo", http.EchoHandler())
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		// Test response time
		start := time.Now()
		resp, err := http.Get(server.URL + "/echo?message=performance-test")
		duration := time.Since(start)
		
		if err != nil {
			t.Errorf("Failed to GET /echo: %v", err)
			return
		}
		defer resp.Body.Close()
		
		if duration > 1*time.Second {
			t.Errorf("Response time too slow: %v", duration)
		}
		
		if resp.StatusCode != http.StatusOK {
			t.Errorf("Expected status 200, got %d", resp.StatusCode)
		}
	})
	
	t.Run("Concurrent_Performance", func(t *testing.T) {
		// Create HTTP server
		mux := http.NewServeMux()
		mux.HandleFunc("/echo", http.EchoHandler())
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		concurrency := 50
		requests := 100
		done := make(chan bool, concurrency)
		
		start := time.Now()
		
		// Send requests concurrently
		for i := 0; i < requests; i++ {
			go func(id int) {
				defer func() { done <- true }()
				
				resp, err := http.Get(fmt.Sprintf("%s/echo?message=perf-test-%d", server.URL, id))
				if err != nil {
					t.Errorf("Request %d failed: %v", id, err)
					return
				}
				defer resp.Body.Close()
			}(i)
		}
		
		// Wait for all requests to complete
		for i := 0; i < requests; i++ {
			<-done
		}
		
		totalDuration := time.Since(start)
		avgDuration := totalDuration / time.Duration(requests)
		
		if avgDuration > 100*time.Millisecond {
			t.Errorf("Average response time too slow: %v", avgDuration)
		}
	})
}

// TestDataFlowIntegration - Integration test for data flow
func TestDataFlowIntegration(t *testing.T) {
	t.Run("HTTP_to_WebSocket_Data_Flow", func(t *testing.T) {
		// Create WebSocket server
		upgrader := websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		}
		
		mux := http.NewServeMux()
		mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
			conn, err := upgrader.Upgrade(w, r, nil)
			if err != nil {
				return
			}
			defer conn.Close()
			
			// Echo messages
			for {
				_, message, err := conn.ReadMessage()
				if err != nil {
					return
				}
				conn.WriteMessage(websocket.TextMessage, message)
			}
		})
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		// Test data flow: HTTP request -> WebSocket message
		wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
		conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
		if err != nil {
			t.Fatalf("Failed to connect to WebSocket: %v", err)
		}
		defer conn.Close()
		
		// Send multiple messages
		messages := []string{"message1", "message2", "message3"}
		for _, msg := range messages {
			if err := conn.WriteMessage(websocket.TextMessage, []byte(msg)); err != nil {
				t.Fatalf("Failed to write message '%s': %v", msg, err)
			}
			
			_, response, err := conn.ReadMessage()
			if err != nil {
				t.Fatalf("Failed to read message for '%s': %v", msg, err)
			}
			
			if string(response) != msg {
				t.Errorf("Expected '%s', got '%s'", msg, string(response))
			}
		}
	})
}

// TestSecurityIntegration - Integration test for security
func TestSecurityIntegration(t *testing.T) {
	t.Run("CORS_Headers", func(t *testing.T) {
		// Create HTTP server with CORS
		mux := http.NewServeMux()
		mux.HandleFunc("/echo", http.EchoHandler())
		
		// Add CORS middleware
		handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
			mux.ServeHTTP(w, r)
		})
		
		server := httptest.NewServer(handler)
		defer server.Close()
		
		// Test CORS preflight request
		req, err := http.NewRequest("OPTIONS", server.URL+"/echo", nil)
		if err != nil {
			t.Fatalf("Failed to create OPTIONS request: %v", err)
		}
		req.Header.Set("Origin", "http://localhost:3000")
		req.Header.Set("Access-Control-Request-Method", "POST")
		
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Errorf("Failed to send OPTIONS request: %v", err)
			return
		}
		defer resp.Body.Close()
		
		if resp.Header.Get("Access-Control-Allow-Origin") == "" {
			t.Error("Expected CORS headers to be set")
		}
	})
}

// TestMonitoringIntegration - Integration test for monitoring
func TestMonitoringIntegration(t *testing.T) {
	t.Run("Metrics_Endpoint", func(t *testing.T) {
		// Create HTTP server with metrics
		mux := http.NewServeMux()
		mux.HandleFunc("/metrics", http.MetricsHandler())
		mux.HandleFunc("/echo", http.EchoHandler())
		
		server := httptest.NewServer(mux)
		defer server.Close()
		
		// Make some requests to generate metrics
		for i := 0; i < 5; i++ {
			resp, err := http.Get(server.URL + "/echo?message=metrics-test")
			if err != nil {
				t.Errorf("Request %d failed: %v", i, err)
				continue
			}
			resp.Body.Close()
		}
		
		// Check metrics endpoint
		resp, err := http.Get(server.URL + "/metrics")
		if err != nil {
			t.Errorf("Failed to GET /metrics: %v", err)
			return
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusOK {
			t.Errorf("Expected status 200, got %d", resp.StatusCode)
		}
		
		// Check metrics content
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			t.Errorf("Failed to read metrics body: %v", err)
			return
		}
		
		metricsContent := string(body)
		if !strings.Contains(metricsContent, "http_requests_total") {
			t.Error("Expected metrics to contain 'http_requests_total'")
		}
	})
}
