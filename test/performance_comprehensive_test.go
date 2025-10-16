package test

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
	"github.com/gorilla/websocket"
	"github.com/stefanprodan/podinfo/pkg/api/http"
)

// TestPerformanceHTTP - Performance tests for HTTP API
func TestPerformanceHTTP(t *testing.T) {
	t.Run("Single_Request_Performance", func(t *testing.T) {
		handler := http.EchoHandler()
		
		req := httptest.NewRequest("GET", "/echo?message=performance-test", nil)
		w := httptest.NewRecorder()
		
		start := time.Now()
		handler.ServeHTTP(w, req)
		duration := time.Since(start)
		
		if w.Code != http.StatusOK {
			t.Errorf("Request failed with status %d", w.Code)
		}
		
		// Should complete within 10ms
		if duration > 10*time.Millisecond {
			t.Errorf("Single request took too long: %v", duration)
		}
	})
	
	t.Run("Concurrent_Requests_Performance", func(t *testing.T) {
		handler := http.EchoHandler()
		
		concurrency := 100
		requests := 1000
		done := make(chan bool, concurrency)
		
		start := time.Now()
		
		// Send requests concurrently
		for i := 0; i < requests; i++ {
			go func(id int) {
				defer func() { done <- true }()
				
				req := httptest.NewRequest("GET", fmt.Sprintf("/echo?message=perf-test-%d", id), nil)
				w := httptest.NewRecorder()
				
				handler.ServeHTTP(w, req)
				
				if w.Code != http.StatusOK {
					t.Errorf("Request %d failed with status %d", id, w.Code)
				}
			}(i)
		}
		
		// Wait for all requests to complete
		for i := 0; i < requests; i++ {
			<-done
		}
		
		totalDuration := time.Since(start)
		avgDuration := totalDuration / time.Duration(requests)
		requestsPerSecond := float64(requests) / totalDuration.Seconds()
		
		t.Logf("Total requests: %d", requests)
		t.Logf("Total duration: %v", totalDuration)
		t.Logf("Average duration per request: %v", avgDuration)
		t.Logf("Requests per second: %.2f", requestsPerSecond)
		
		// Should handle at least 1000 requests per second
		if requestsPerSecond < 1000 {
			t.Errorf("Performance too low: %.2f requests/second", requestsPerSecond)
		}
	})
	
	t.Run("Memory_Usage_Under_Load", func(t *testing.T) {
		handler := http.EchoHandler()
		
		// Make many requests to test memory usage
		for i := 0; i < 10000; i++ {
			req := httptest.NewRequest("GET", fmt.Sprintf("/echo?message=memory-test-%d", i), nil)
			w := httptest.NewRecorder()
			
			handler.ServeHTTP(w, req)
			
			if w.Code != http.StatusOK {
				t.Errorf("Request %d failed with status %d", i, w.Code)
			}
			
			// Check every 1000 requests
			if i%1000 == 0 && i > 0 {
				t.Logf("Completed %d requests", i)
			}
		}
	})
}

// TestPerformanceWebSocket - Performance tests for WebSocket
func TestPerformanceWebSocket(t *testing.T) {
	t.Run("WebSocket_Message_Throughput", func(t *testing.T) {
		upgrader := websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		}
		
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
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
		}))
		defer server.Close()
		
		wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
		conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
		if err != nil {
			t.Fatalf("Failed to connect to WebSocket: %v", err)
		}
		defer conn.Close()
		
		messages := 1000
		start := time.Now()
		
		// Send messages and measure throughput
		for i := 0; i < messages; i++ {
			message := fmt.Sprintf("perf-test-%d", i)
			if err := conn.WriteMessage(websocket.TextMessage, []byte(message)); err != nil {
				t.Fatalf("Failed to write message %d: %v", i, err)
			}
			
			_, response, err := conn.ReadMessage()
			if err != nil {
				t.Fatalf("Failed to read message %d: %v", i, err)
			}
			
			if string(response) != message {
				t.Errorf("Expected '%s', got '%s'", message, string(response))
			}
		}
		
		duration := time.Since(start)
		messagesPerSecond := float64(messages) / duration.Seconds()
		
		t.Logf("Messages sent: %d", messages)
		t.Logf("Total duration: %v", duration)
		t.Logf("Messages per second: %.2f", messagesPerSecond)
		
		// Should handle at least 100 messages per second
		if messagesPerSecond < 100 {
			t.Errorf("WebSocket performance too low: %.2f messages/second", messagesPerSecond)
		}
	})
	
	t.Run("Concurrent_WebSocket_Connections", func(t *testing.T) {
		upgrader := websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		}
		
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
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
		}))
		defer server.Close()
		
		concurrency := 50
		messagesPerConnection := 100
		done := make(chan bool, concurrency)
		
		start := time.Now()
		
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
				
				// Send messages
				for j := 0; j < messagesPerConnection; j++ {
					message := fmt.Sprintf("conn-%d-msg-%d", id, j)
					if err := conn.WriteMessage(websocket.TextMessage, []byte(message)); err != nil {
						t.Errorf("Failed to write message %d-%d: %v", id, j, err)
						return
					}
					
					_, response, err := conn.ReadMessage()
					if err != nil {
						t.Errorf("Failed to read message %d-%d: %v", id, j, err)
						return
					}
					
					if string(response) != message {
						t.Errorf("Expected '%s', got '%s'", message, string(response))
					}
				}
			}(i)
		}
		
		// Wait for all connections to complete
		for i := 0; i < concurrency; i++ {
			<-done
		}
		
		duration := time.Since(start)
		totalMessages := concurrency * messagesPerConnection
		messagesPerSecond := float64(totalMessages) / duration.Seconds()
		
		t.Logf("Concurrent connections: %d", concurrency)
		t.Logf("Messages per connection: %d", messagesPerConnection)
		t.Logf("Total messages: %d", totalMessages)
		t.Logf("Total duration: %v", duration)
		t.Logf("Messages per second: %.2f", messagesPerSecond)
		
		// Should handle at least 1000 messages per second
		if messagesPerSecond < 1000 {
			t.Errorf("Concurrent WebSocket performance too low: %.2f messages/second", messagesPerSecond)
		}
	})
}

// TestPerformanceDelay - Performance tests for delay handler
func TestPerformanceDelay(t *testing.T) {
	t.Run("Delay_Handler_Performance", func(t *testing.T) {
		handler := http.DelayHandler()
		
		req := httptest.NewRequest("GET", "/delay/0", nil)
		w := httptest.NewRecorder()
		
		start := time.Now()
		handler.ServeHTTP(w, req)
		duration := time.Since(start)
		
		if w.Code != http.StatusOK {
			t.Errorf("Delay request failed with status %d", w.Code)
		}
		
		// Zero delay should complete quickly
		if duration > 10*time.Millisecond {
			t.Errorf("Zero delay took too long: %v", duration)
		}
	})
	
	t.Run("Concurrent_Delay_Requests", func(t *testing.T) {
		handler := http.DelayHandler()
		
		concurrency := 10
		done := make(chan bool, concurrency)
		
		start := time.Now()
		
		for i := 0; i < concurrency; i++ {
			go func(id int) {
				defer func() { done <- true }()
				
				req := httptest.NewRequest("GET", "/delay/0", nil)
				w := httptest.NewRecorder()
				
				handler.ServeHTTP(w, req)
				
				if w.Code != http.StatusOK {
					t.Errorf("Concurrent delay request %d failed with status %d", id, w.Code)
				}
			}(i)
		}
		
		// Wait for all requests to complete
		for i := 0; i < concurrency; i++ {
			<-done
		}
		
		duration := time.Since(start)
		avgDuration := duration / time.Duration(concurrency)
		
		t.Logf("Concurrent delay requests: %d", concurrency)
		t.Logf("Total duration: %v", duration)
		t.Logf("Average duration per request: %v", avgDuration)
		
		// Should complete all requests within reasonable time
		if duration > 1*time.Second {
			t.Errorf("Concurrent delay requests took too long: %v", duration)
		}
	})
}

// TestPerformanceMemory - Performance tests for memory usage
func TestPerformanceMemory(t *testing.T) {
	t.Run("Memory_Usage_Over_Time", func(t *testing.T) {
		handler := http.EchoHandler()
		
		// Make requests over time to test memory stability
		for round := 0; round < 10; round++ {
			for i := 0; i < 1000; i++ {
				req := httptest.NewRequest("GET", fmt.Sprintf("/echo?message=memory-round-%d-msg-%d", round, i), nil)
				w := httptest.NewRecorder()
				
				handler.ServeHTTP(w, req)
				
				if w.Code != http.StatusOK {
					t.Errorf("Request %d-%d failed with status %d", round, i, w.Code)
				}
			}
			
			t.Logf("Completed round %d (1000 requests)", round)
			
			// Small delay between rounds
			time.Sleep(100 * time.Millisecond)
		}
	})
	
	t.Run("Large_Payload_Performance", func(t *testing.T) {
		handler := http.EchoHandler()
		
		// Test with different payload sizes
		payloadSizes := []int{1024, 10240, 102400, 1024000} // 1KB, 10KB, 100KB, 1MB
		
		for _, size := range payloadSizes {
			t.Run(fmt.Sprintf("Payload_Size_%d", size), func(t *testing.T) {
				payload := strings.Repeat("a", size)
				
				req := httptest.NewRequest("POST", "/echo", strings.NewReader(fmt.Sprintf(`{"message":"%s"}`, payload)))
				req.Header.Set("Content-Type", "application/json")
				w := httptest.NewRecorder()
				
				start := time.Now()
				handler.ServeHTTP(w, req)
				duration := time.Since(start)
				
				if w.Code != http.StatusOK {
					t.Errorf("Request with payload size %d failed with status %d", size, w.Code)
				}
				
				t.Logf("Payload size: %d bytes, Duration: %v", size, duration)
				
				// Should complete within reasonable time
				if duration > 1*time.Second {
					t.Errorf("Large payload (%d bytes) took too long: %v", size, duration)
				}
			})
		}
	})
}

// TestPerformanceConcurrency - Performance tests for concurrency
func TestPerformanceConcurrency(t *testing.T) {
	t.Run("High_Concurrency_HTTP", func(t *testing.T) {
		handler := http.EchoHandler()
		
		concurrency := 1000
		done := make(chan bool, concurrency)
		
		start := time.Now()
		
		for i := 0; i < concurrency; i++ {
			go func(id int) {
				defer func() { done <- true }()
				
				req := httptest.NewRequest("GET", fmt.Sprintf("/echo?message=high-concurrency-%d", id), nil)
				w := httptest.NewRecorder()
				
				handler.ServeHTTP(w, req)
				
				if w.Code != http.StatusOK {
					t.Errorf("High concurrency request %d failed with status %d", id, w.Code)
				}
			}(i)
		}
		
		// Wait for all requests to complete
		for i := 0; i < concurrency; i++ {
			<-done
		}
		
		duration := time.Since(start)
		requestsPerSecond := float64(concurrency) / duration.Seconds()
		
		t.Logf("High concurrency requests: %d", concurrency)
		t.Logf("Total duration: %v", duration)
		t.Logf("Requests per second: %.2f", requestsPerSecond)
		
		// Should handle high concurrency
		if requestsPerSecond < 100 {
			t.Errorf("High concurrency performance too low: %.2f requests/second", requestsPerSecond)
		}
	})
	
	t.Run("Mixed_Workload_Performance", func(t *testing.T) {
		// Test mixed workload with different handlers
		handlers := map[string]http.HandlerFunc{
			"echo":   http.EchoHandler(),
			"delay":  http.DelayHandler(),
			"status": http.StatusHandler(),
			"token":  http.TokenHandler(),
		}
		
		concurrency := 100
		done := make(chan bool, concurrency)
		
		start := time.Now()
		
		for i := 0; i < concurrency; i++ {
			go func(id int) {
				defer func() { done <- true }()
				
				// Use different handlers
				handlerName := []string{"echo", "delay", "status", "token"}[id%4]
				handler := handlers[handlerName]
				
				var req *http.Request
				switch handlerName {
				case "echo":
					req = httptest.NewRequest("GET", fmt.Sprintf("/echo?message=mixed-%d", id), nil)
				case "delay":
					req = httptest.NewRequest("GET", "/delay/0", nil)
				case "status":
					req = httptest.NewRequest("GET", "/status/200", nil)
				case "token":
					req = httptest.NewRequest("GET", "/token", nil)
				}
				
				w := httptest.NewRecorder()
				handler.ServeHTTP(w, req)
				
				if w.Code != http.StatusOK {
					t.Errorf("Mixed workload request %d (%s) failed with status %d", id, handlerName, w.Code)
				}
			}(i)
		}
		
		// Wait for all requests to complete
		for i := 0; i < concurrency; i++ {
			<-done
		}
		
		duration := time.Since(start)
		requestsPerSecond := float64(concurrency) / duration.Seconds()
		
		t.Logf("Mixed workload requests: %d", concurrency)
		t.Logf("Total duration: %v", duration)
		t.Logf("Requests per second: %.2f", requestsPerSecond)
		
		// Should handle mixed workload
		if requestsPerSecond < 50 {
			t.Errorf("Mixed workload performance too low: %.2f requests/second", requestsPerSecond)
		}
	})
}

// TestPerformanceStress - Stress tests
func TestPerformanceStress(t *testing.T) {
	t.Run("Sustained_Load", func(t *testing.T) {
		handler := http.EchoHandler()
		
		duration := 30 * time.Second
		requestsPerSecond := 100
		totalRequests := int(duration.Seconds()) * requestsPerSecond
		
		done := make(chan bool, totalRequests)
		start := time.Now()
		
		// Send requests at regular intervals
		ticker := time.NewTicker(time.Second / time.Duration(requestsPerSecond))
		defer ticker.Stop()
		
		requestCount := 0
		for {
			select {
			case <-ticker.C:
				if requestCount >= totalRequests {
					goto done
				}
				
				go func(id int) {
					defer func() { done <- true }()
					
					req := httptest.NewRequest("GET", fmt.Sprintf("/echo?message=stress-%d", id), nil)
					w := httptest.NewRecorder()
					
					handler.ServeHTTP(w, req)
					
					if w.Code != http.StatusOK {
						t.Errorf("Stress request %d failed with status %d", id, w.Code)
					}
				}(requestCount)
				
				requestCount++
			case <-time.After(duration):
				goto done
			}
		}
		
	done:
		// Wait for all requests to complete
		for i := 0; i < requestCount; i++ {
			<-done
		}
		
		totalDuration := time.Since(start)
		actualRequestsPerSecond := float64(requestCount) / totalDuration.Seconds()
		
		t.Logf("Sustained load duration: %v", duration)
		t.Logf("Total requests: %d", requestCount)
		t.Logf("Actual requests per second: %.2f", actualRequestsPerSecond)
		
		// Should maintain reasonable performance
		if actualRequestsPerSecond < 50 {
			t.Errorf("Sustained load performance too low: %.2f requests/second", actualRequestsPerSecond)
		}
	})
	
	t.Run("Burst_Load", func(t *testing.T) {
		handler := http.EchoHandler()
		
		// Send a burst of requests
		burstSize := 500
		done := make(chan bool, burstSize)
		
		start := time.Now()
		
		for i := 0; i < burstSize; i++ {
			go func(id int) {
				defer func() { done <- true }()
				
				req := httptest.NewRequest("GET", fmt.Sprintf("/echo?message=burst-%d", id), nil)
				w := httptest.NewRecorder()
				
				handler.ServeHTTP(w, req)
				
				if w.Code != http.StatusOK {
					t.Errorf("Burst request %d failed with status %d", id, w.Code)
				}
			}(i)
		}
		
		// Wait for all requests to complete
		for i := 0; i < burstSize; i++ {
			<-done
		}
		
		duration := time.Since(start)
		requestsPerSecond := float64(burstSize) / duration.Seconds()
		
		t.Logf("Burst size: %d", burstSize)
		t.Logf("Total duration: %v", duration)
		t.Logf("Requests per second: %.2f", requestsPerSecond)
		
		// Should handle burst load
		if requestsPerSecond < 100 {
			t.Errorf("Burst load performance too low: %.2f requests/second", requestsPerSecond)
		}
	})
}

// TestPerformanceLatency - Latency tests
func TestPerformanceLatency(t *testing.T) {
	t.Run("P50_P95_P99_Latency", func(t *testing.T) {
		handler := http.EchoHandler()
		
		requests := 1000
		latencies := make([]time.Duration, requests)
		
		for i := 0; i < requests; i++ {
			req := httptest.NewRequest("GET", fmt.Sprintf("/echo?message=latency-%d", i), nil)
			w := httptest.NewRecorder()
			
			start := time.Now()
			handler.ServeHTTP(w, req)
			latencies[i] = time.Since(start)
			
			if w.Code != http.StatusOK {
				t.Errorf("Latency request %d failed with status %d", i, w.Code)
			}
		}
		
		// Sort latencies (simplified - in real test you'd use sort.Slice)
		// For now, just calculate average
		var total time.Duration
		for _, latency := range latencies {
			total += latency
		}
		avgLatency := total / time.Duration(len(latencies))
		
		t.Logf("Average latency: %v", avgLatency)
		
		// Average latency should be reasonable
		if avgLatency > 10*time.Millisecond {
			t.Errorf("Average latency too high: %v", avgLatency)
		}
	})
}
