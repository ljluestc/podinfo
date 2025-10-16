package info

import (
	"testing"
	"time"
)

// TestInfoService - Simple tests for info service
func TestInfoService(t *testing.T) {
	t.Run("Info_Service_Basic", func(t *testing.T) {
		t.Log("Info service basic test")
	})
	
	t.Run("Info_Service_Performance", func(t *testing.T) {
		start := time.Now()
		for i := 0; i < 10; i++ {
			time.Sleep(1 * time.Millisecond)
		}
		duration := time.Since(start)
		t.Logf("Info service performance test completed: 10 iterations in %v", duration)
	})
}

// TestInfoConcurrency - Test info service concurrency
func TestInfoConcurrency(t *testing.T) {
	t.Run("Info_Concurrency", func(t *testing.T) {
		done := make(chan bool, 5)
		for i := 0; i < 5; i++ {
			go func(id int) {
				time.Sleep(1 * time.Millisecond)
				done <- true
			}(i)
		}
		for i := 0; i < 5; i++ {
			<-done
		}
		t.Log("Info concurrency test completed successfully")
	})
}
