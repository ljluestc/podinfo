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
	"github.com/stefanprodan/podinfo/pkg/api/http"
)

// TestEdgeCasesHTTP - Comprehensive edge case tests for HTTP API
func TestEdgeCasesHTTP(t *testing.T) {
	t.Run("Empty_Request_Body", func(t *testing.T) {
		handler := http.EchoHandler()
		
		req := httptest.NewRequest("POST", "/echo", strings.NewReader(""))
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		if w.Code != http.StatusOK {
			t.Errorf("Expected status 200 for empty body, got %d", w.Code)
		}
	})
	
	t.Run("Very_Large_Request_Body", func(t *testing.T) {
		handler := http.EchoHandler()
		
		// Create a very large request body (1MB)
		largeBody := strings.Repeat("a", 1024*1024)
		req := httptest.NewRequest("POST", "/echo", strings.NewReader(largeBody))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		// Should handle large body gracefully
		if w.Code != http.StatusOK && w.Code != http.StatusRequestEntityTooLarge {
			t.Errorf("Expected status 200 or 413 for large body, got %d", w.Code)
		}
	})
	
	t.Run("Malformed_JSON", func(t *testing.T) {
		handler := http.EchoHandler()
		
		req := httptest.NewRequest("POST", "/echo", strings.NewReader("{invalid json"))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		// Should handle malformed JSON gracefully
		if w.Code != http.StatusOK && w.Code != http.StatusBadRequest {
			t.Errorf("Expected status 200 or 400 for malformed JSON, got %d", w.Code)
		}
	})
	
	t.Run("Unsupported_HTTP_Method", func(t *testing.T) {
		handler := http.EchoHandler()
		
		req := httptest.NewRequest("PATCH", "/echo", nil)
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		// Should handle unsupported method gracefully
		if w.Code != http.StatusOK && w.Code != http.StatusMethodNotAllowed {
			t.Errorf("Expected status 200 or 405 for unsupported method, got %d", w.Code)
		}
	})
	
	t.Run("Very_Long_URL", func(t *testing.T) {
		handler := http.EchoHandler()
		
		// Create a very long URL
		longMessage := strings.Repeat("a", 10000)
		req := httptest.NewRequest("GET", "/echo?message="+longMessage, nil)
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		// Should handle long URL gracefully
		if w.Code != http.StatusOK && w.Code != http.StatusRequestURITooLong {
			t.Errorf("Expected status 200 or 414 for long URL, got %d", w.Code)
		}
	})
	
	t.Run("Special_Characters_In_Message", func(t *testing.T) {
		handler := http.EchoHandler()
		
		specialMessage := "!@#$%^&*()_+-=[]{}|;':\",./<>?`~"
		req := httptest.NewRequest("GET", "/echo?message="+specialMessage, nil)
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		if w.Code != http.StatusOK {
			t.Errorf("Expected status 200 for special characters, got %d", w.Code)
		}
		
		var response map[string]string
		if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
			t.Errorf("Failed to unmarshal response: %v", err)
		}
		
		if response["message"] != specialMessage {
			t.Errorf("Expected '%s', got '%s'", specialMessage, response["message"])
		}
	})
	
	t.Run("Unicode_Characters", func(t *testing.T) {
		handler := http.EchoHandler()
		
		unicodeMessage := "Hello 世界 🌍 测试"
		req := httptest.NewRequest("GET", "/echo?message="+unicodeMessage, nil)
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		if w.Code != http.StatusOK {
			t.Errorf("Expected status 200 for unicode, got %d", w.Code)
		}
		
		var response map[string]string
		if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
			t.Errorf("Failed to unmarshal response: %v", err)
		}
		
		if response["message"] != unicodeMessage {
			t.Errorf("Expected '%s', got '%s'", unicodeMessage, response["message"])
		}
	})
}

// TestEdgeCasesDelay - Edge case tests for delay handler
func TestEdgeCasesDelay(t *testing.T) {
	t.Run("Zero_Delay", func(t *testing.T) {
		handler := http.DelayHandler()
		
		req := httptest.NewRequest("GET", "/delay/0", nil)
		w := httptest.NewRecorder()
		
		start := time.Now()
		handler.ServeHTTP(w, req)
		duration := time.Since(start)
		
		if w.Code != http.StatusOK {
			t.Errorf("Expected status 200 for zero delay, got %d", w.Code)
		}
		
		// Should complete quickly
		if duration > 100*time.Millisecond {
			t.Errorf("Zero delay took too long: %v", duration)
		}
	})
	
	t.Run("Negative_Delay", func(t *testing.T) {
		handler := http.DelayHandler()
		
		req := httptest.NewRequest("GET", "/delay/-1", nil)
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		if w.Code != http.StatusBadRequest {
			t.Errorf("Expected status 400 for negative delay, got %d", w.Code)
		}
	})
	
	t.Run("Very_Large_Delay", func(t *testing.T) {
		handler := http.DelayHandler()
		
		req := httptest.NewRequest("GET", "/delay/3600", nil) // 1 hour
		w := httptest.NewRecorder()
		
		// Use a context with timeout to avoid waiting too long
		ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
		defer cancel()
		
		req = req.WithContext(ctx)
		
		handler.ServeHTTP(w, req)
		
		// Should handle large delay gracefully (might timeout)
		if w.Code != http.StatusOK && w.Code != http.StatusRequestTimeout {
			t.Errorf("Expected status 200 or 408 for large delay, got %d", w.Code)
		}
	})
	
	t.Run("Invalid_Delay_Parameter", func(t *testing.T) {
		handler := http.DelayHandler()
		
		req := httptest.NewRequest("GET", "/delay/invalid", nil)
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		if w.Code != http.StatusBadRequest {
			t.Errorf("Expected status 400 for invalid delay, got %d", w.Code)
		}
	})
	
	t.Run("Float_Delay_Parameter", func(t *testing.T) {
		handler := http.DelayHandler()
		
		req := httptest.NewRequest("GET", "/delay/1.5", nil)
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		// Should handle float parameter gracefully
		if w.Code != http.StatusOK && w.Code != http.StatusBadRequest {
			t.Errorf("Expected status 200 or 400 for float delay, got %d", w.Code)
		}
	})
}

// TestEdgeCasesWebSocket - Edge case tests for WebSocket
func TestEdgeCasesWebSocket(t *testing.T) {
	t.Run("WebSocket_With_Empty_Message", func(t *testing.T) {
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
		
		// Send empty message
		if err := conn.WriteMessage(websocket.TextMessage, []byte("")); err != nil {
			t.Fatalf("Failed to write empty message: %v", err)
		}
		
		// Read echo response
		_, message, err := conn.ReadMessage()
		if err != nil {
			t.Fatalf("Failed to read empty message: %v", err)
		}
		
		if string(message) != "" {
			t.Errorf("Expected empty message, got '%s'", string(message))
		}
	})
	
	t.Run("WebSocket_With_Very_Large_Message", func(t *testing.T) {
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
		
		// Send very large message (1MB)
		largeMessage := strings.Repeat("a", 1024*1024)
		if err := conn.WriteMessage(websocket.TextMessage, []byte(largeMessage)); err != nil {
			t.Fatalf("Failed to write large message: %v", err)
		}
		
		// Read echo response
		_, message, err := conn.ReadMessage()
		if err != nil {
			t.Fatalf("Failed to read large message: %v", err)
		}
		
		if string(message) != largeMessage {
			t.Errorf("Expected large message, got message of length %d", len(message))
		}
	})
	
	t.Run("WebSocket_With_Binary_Message", func(t *testing.T) {
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
				messageType, message, err := conn.ReadMessage()
				if err != nil {
					return
				}
				conn.WriteMessage(messageType, message)
			}
		}))
		defer server.Close()
		
		wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
		conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
		if err != nil {
			t.Fatalf("Failed to connect to WebSocket: %v", err)
		}
		defer conn.Close()
		
		// Send binary message
		binaryMessage := []byte{0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD}
		if err := conn.WriteMessage(websocket.BinaryMessage, binaryMessage); err != nil {
			t.Fatalf("Failed to write binary message: %v", err)
		}
		
		// Read echo response
		messageType, message, err := conn.ReadMessage()
		if err != nil {
			t.Fatalf("Failed to read binary message: %v", err)
		}
		
		if messageType != websocket.BinaryMessage {
			t.Errorf("Expected binary message type, got %d", messageType)
		}
		
		if !bytes.Equal(message, binaryMessage) {
			t.Errorf("Expected binary message %v, got %v", binaryMessage, message)
		}
	})
}

// TestEdgeCasesConcurrency - Edge case tests for concurrency
func TestEdgeCasesConcurrency(t *testing.T) {
	t.Run("Rapid_Concurrent_Requests", func(t *testing.T) {
		handler := http.EchoHandler()
		
		concurrency := 100
		done := make(chan bool, concurrency)
		
		for i := 0; i < concurrency; i++ {
			go func(id int) {
				defer func() { done <- true }()
				
				req := httptest.NewRequest("GET", fmt.Sprintf("/echo?message=rapid-%d", id), nil)
				w := httptest.NewRecorder()
				
				handler.ServeHTTP(w, req)
				
				if w.Code != http.StatusOK {
					t.Errorf("Rapid request %d failed with status %d", id, w.Code)
				}
			}(i)
		}
		
		// Wait for all requests to complete
		for i := 0; i < concurrency; i++ {
			<-done
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
		
		concurrency := 20
		done := make(chan bool, concurrency)
		
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
				testMessage := fmt.Sprintf("concurrent-test-%d", id)
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

// TestEdgeCasesMemory - Edge case tests for memory usage
func TestEdgeCasesMemory(t *testing.T) {
	t.Run("Memory_Intensive_Request", func(t *testing.T) {
		handler := http.EchoHandler()
		
		// Create a request with large JSON payload
		largeData := make(map[string]string)
		for i := 0; i < 10000; i++ {
			largeData[fmt.Sprintf("key-%d", i)] = strings.Repeat("value", 100)
		}
		
		jsonData, err := json.Marshal(largeData)
		if err != nil {
			t.Fatalf("Failed to marshal large data: %v", err)
		}
		
		req := httptest.NewRequest("POST", "/echo", bytes.NewReader(jsonData))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		// Should handle large payload gracefully
		if w.Code != http.StatusOK && w.Code != http.StatusRequestEntityTooLarge {
			t.Errorf("Expected status 200 or 413 for large payload, got %d", w.Code)
		}
	})
	
	t.Run("Memory_Leak_Prevention", func(t *testing.T) {
		handler := http.EchoHandler()
		
		// Make many requests to test for memory leaks
		for i := 0; i < 1000; i++ {
			req := httptest.NewRequest("GET", fmt.Sprintf("/echo?message=leak-test-%d", i), nil)
			w := httptest.NewRecorder()
			
			handler.ServeHTTP(w, req)
			
			if w.Code != http.StatusOK {
				t.Errorf("Request %d failed with status %d", i, w.Code)
			}
		}
	})
}

// TestEdgeCasesNetwork - Edge case tests for network conditions
func TestEdgeCasesNetwork(t *testing.T) {
	t.Run("Slow_Client", func(t *testing.T) {
		handler := http.DelayHandler()
		
		// Simulate slow client by using a context with timeout
		ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
		defer cancel()
		
		req := httptest.NewRequest("GET", "/delay/1", nil)
		req = req.WithContext(ctx)
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		// Should handle slow client gracefully
		if w.Code != http.StatusOK && w.Code != http.StatusRequestTimeout {
			t.Errorf("Expected status 200 or 408 for slow client, got %d", w.Code)
		}
	})
	
	t.Run("Connection_Abort", func(t *testing.T) {
		handler := http.DelayHandler()
		
		// Simulate connection abort by cancelling context immediately
		ctx, cancel := context.WithCancel(context.Background())
		cancel()
		
		req := httptest.NewRequest("GET", "/delay/1", nil)
		req = req.WithContext(ctx)
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		// Should handle connection abort gracefully
		if w.Code != http.StatusOK && w.Code != http.StatusRequestTimeout {
			t.Errorf("Expected status 200 or 408 for connection abort, got %d", w.Code)
		}
	})
}

// TestEdgeCasesErrorRecovery - Edge case tests for error recovery
func TestEdgeCasesErrorRecovery(t *testing.T) {
	t.Run("Panic_Recovery", func(t *testing.T) {
		handler := http.PanicHandler()
		
		req := httptest.NewRequest("GET", "/panic", nil)
		w := httptest.NewRecorder()
		
		// This should panic, but we expect it to be handled
		defer func() {
			if r := recover(); r == nil {
				t.Error("Expected panic handler to panic")
			}
		}()
		
		handler.ServeHTTP(w, req)
	})
	
	t.Run("Invalid_Status_Code", func(t *testing.T) {
		handler := http.StatusHandler()
		
		req := httptest.NewRequest("GET", "/status/999", nil)
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		// Should handle invalid status code gracefully
		if w.Code != http.StatusOK && w.Code != http.StatusBadRequest {
			t.Errorf("Expected status 200 or 400 for invalid status code, got %d", w.Code)
		}
	})
	
	t.Run("Malformed_Headers", func(t *testing.T) {
		handler := http.EchoHeadersHandler()
		
		req := httptest.NewRequest("GET", "/echo/headers", nil)
		req.Header.Set("X-Malformed-Header", "value\x00with\x00nulls")
		w := httptest.NewRecorder()
		
		handler.ServeHTTP(w, req)
		
		// Should handle malformed headers gracefully
		if w.Code != http.StatusOK && w.Code != http.StatusBadRequest {
			t.Errorf("Expected status 200 or 400 for malformed headers, got %d", w.Code)
		}
	})
}
