package version

import (
	"testing"
	"time"
)

func TestVersion(t *testing.T) {
	// Test that VERSION is not empty
	if VERSION == "" {
		t.Error("VERSION is empty")
	}
	
	// Test that VERSION returns a valid version format
	// Version should be in format like "6.9.2"
	if len(VERSION) < 3 {
		t.Errorf("VERSION string too short: %s", VERSION)
	}
}

func TestVersionConsistency(t *testing.T) {
	// Test that VERSION returns the same value multiple times
	v1 := VERSION
	v2 := VERSION
	
	if v1 != v2 {
		t.Errorf("VERSION inconsistent: first call returned %s, second call returned %s", v1, v2)
	}
}

func TestVersionConcurrent(t *testing.T) {
	// Test VERSION under concurrent access
	done := make(chan string, 10)
	
	for i := 0; i < 10; i++ {
		go func() {
			v := VERSION
			done <- v
		}()
	}
	
	// Collect all versions
	versions := make([]string, 10)
	for i := 0; i < 10; i++ {
		select {
		case v := <-done:
			versions[i] = v
		}
	}
	
	// All versions should be the same
	firstVersion := versions[0]
	for i, v := range versions {
		if v != firstVersion {
			t.Errorf("Concurrent version call %d returned %s, expected %s", i, v, firstVersion)
		}
	}
}

func TestVersionFormat(t *testing.T) {
	v := VERSION
	
	// Test that version contains at least one dot (for semantic versioning)
	hasDot := false
	for _, char := range v {
		if char == '.' {
			hasDot = true
			break
		}
	}
	
	if !hasDot {
		t.Errorf("VERSION %s does not contain a dot (not semantic versioning format)", v)
	}
}

func TestVersionNonEmpty(t *testing.T) {
	// Test that VERSION is not empty and not just whitespace
	v := VERSION
	
	if len(v) == 0 {
		t.Error("VERSION is empty")
	}
	
	// Check for whitespace-only version
	allWhitespace := true
	for _, char := range v {
		if char != ' ' && char != '\t' && char != '\n' && char != '\r' {
			allWhitespace = false
			break
		}
	}
	
	if allWhitespace {
		t.Error("VERSION contains only whitespace")
	}
}

func TestVersionStability(t *testing.T) {
	// Test that VERSION doesn't change between calls
	versions := make([]string, 100)
	
	for i := 0; i < 100; i++ {
		versions[i] = VERSION
	}
	
	// All versions should be identical
	firstVersion := versions[0]
	for i, v := range versions {
		if v != firstVersion {
			t.Errorf("VERSION changed at call %d: expected %s, got %s", i, firstVersion, v)
		}
	}
}

func TestVersionPerformance(t *testing.T) {
	// Test that VERSION is fast to access
	iterations := 10000
	
	// Warm up
	for i := 0; i < 100; i++ {
		_ = VERSION
	}
	
	// Measure performance
	start := time.Now()
	for i := 0; i < iterations; i++ {
		_ = VERSION
	}
	elapsed := time.Since(start)
	
	// VERSION should be very fast (constant)
	avgTime := elapsed / time.Duration(iterations)
	if avgTime > time.Microsecond {
		t.Errorf("VERSION access took too long on average: %v", avgTime)
	}
}

func TestVersionWithDifferentGoRoutines(t *testing.T) {
	// Test VERSION from different goroutines
	versions := make([]string, 5)
	done := make(chan bool, 5)
	
	for i := 0; i < 5; i++ {
		go func(index int) {
			versions[index] = VERSION
			done <- true
		}(i)
	}
	
	// Wait for all goroutines to complete
	for i := 0; i < 5; i++ {
		<-done
	}
	
	// All versions should be the same
	firstVersion := versions[0]
	for i, v := range versions {
		if v != firstVersion {
			t.Errorf("VERSION from goroutine %d returned %s, expected %s", i, v, firstVersion)
		}
	}
}

func TestVersionAfterPanic(t *testing.T) {
	// Test that VERSION still works after a panic
	defer func() {
		if r := recover(); r != nil {
			// Expected panic
		}
		
		// VERSION should still work after panic
		v := VERSION
		if v == "" {
			t.Error("VERSION returned empty string after panic")
		}
	}()
	
	// Cause a panic
	panic("test panic")
}

func TestVersionEdgeCases(t *testing.T) {
	// Test VERSION in various edge cases
	
	// Test after multiple calls
	for i := 0; i < 1000; i++ {
		v := VERSION
		if v == "" {
			t.Errorf("VERSION returned empty string at iteration %d", i)
		}
	}
	
	// Test in a loop with other operations
	for i := 0; i < 100; i++ {
		// Do some other work
		_ = i * 2
		
		v := VERSION
		if v == "" {
			t.Errorf("VERSION returned empty string in loop iteration %d", i)
		}
	}
}

func TestRevision(t *testing.T) {
	// Test REVISION variable
	if REVISION == "" {
		t.Error("REVISION is empty")
	}
	
	// REVISION should be consistent
	r1 := REVISION
	r2 := REVISION
	
	if r1 != r2 {
		t.Errorf("REVISION inconsistent: first call returned %s, second call returned %s", r1, r2)
	}
}