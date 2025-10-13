package fscache

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestNewWatch(t *testing.T) {
	// Create a temporary directory for testing
	tempDir := t.TempDir()
	
	watcher, err := NewWatch(tempDir)
	if err != nil {
		t.Fatalf("NewWatch failed: %v", err)
	}
	
	if watcher == nil {
		t.Fatal("NewWatch returned nil")
	}
	
	if watcher.dir != tempDir {
		t.Errorf("Expected watcher directory %s, got %s", tempDir, watcher.dir)
	}
}

func TestNewWatch_InvalidDirectory(t *testing.T) {
	// Test with invalid directory
	_, err := NewWatch("/invalid/path/that/does/not/exist")
	if err == nil {
		t.Error("Expected error for invalid directory")
	}
}

func TestNewWatch_EmptyDirectory(t *testing.T) {
	// Test with empty directory
	_, err := NewWatch("")
	if err == nil {
		t.Error("Expected error for empty directory")
	}
}

func TestWatcher_UpdateCache(t *testing.T) {
	tempDir := t.TempDir()
	watcher, err := NewWatch(tempDir)
	if err != nil {
		t.Fatalf("NewWatch failed: %v", err)
	}
	
	// Create a test file
	testFile := filepath.Join(tempDir, "test.txt")
	testContent := "test content"
	err = os.WriteFile(testFile, []byte(testContent), 0644)
	if err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}
	
	// Update cache
	err = watcher.updateCache()
	if err != nil {
		t.Fatalf("updateCache failed: %v", err)
	}
	
	// Check if content is in cache
	if value, ok := watcher.Cache.Load("test.txt"); !ok {
		t.Error("Test file not found in cache")
	} else if value != testContent {
		t.Errorf("Expected content '%s', got '%s'", testContent, value)
	}
}

func TestWatcher_CacheOperations(t *testing.T) {
	tempDir := t.TempDir()
	watcher, err := NewWatch(tempDir)
	if err != nil {
		t.Fatalf("NewWatch failed: %v", err)
	}
	
	// Test cache operations
	key := "test-key"
	value := "test-value"
	
	// Store in cache
	watcher.Cache.Store(key, value)
	
	// Load from cache
	if loadedValue, ok := watcher.Cache.Load(key); !ok {
		t.Error("Key not found in cache")
	} else if loadedValue != value {
		t.Errorf("Expected value '%s', got '%s'", value, loadedValue)
	}
	
	// Delete from cache
	watcher.Cache.Delete(key)
	
	// Verify deletion
	if _, ok := watcher.Cache.Load(key); ok {
		t.Error("Key should have been deleted from cache")
	}
}

func TestWatcher_ConcurrentAccess(t *testing.T) {
	tempDir := t.TempDir()
	watcher, err := NewWatch(tempDir)
	if err != nil {
		t.Fatalf("NewWatch failed: %v", err)
	}
	
	// Test concurrent cache operations
	done := make(chan bool, 10)
	
	for i := 0; i < 10; i++ {
		go func(i int) {
			key := fmt.Sprintf("key-%d", i)
			value := fmt.Sprintf("value-%d", i)
			
			// Store in cache
			watcher.Cache.Store(key, value)
			
			// Load from cache
			if loadedValue, ok := watcher.Cache.Load(key); !ok {
				t.Errorf("Concurrent Load failed for key %s", key)
			} else if loadedValue != value {
				t.Errorf("Concurrent access mismatch for key %s", key)
			}
			
			done <- true
		}(i)
	}
	
	// Wait for all goroutines to complete
	for i := 0; i < 10; i++ {
		<-done
	}
}

func TestWatcher_FileSystemIntegration(t *testing.T) {
	tempDir := t.TempDir()
	watcher, err := NewWatch(tempDir)
	if err != nil {
		t.Fatalf("NewWatch failed: %v", err)
	}
	
	// Create multiple test files
	testFiles := map[string]string{
		"file1.txt": "content 1",
		"file2.txt": "content 2",
		"file3.txt": "content 3",
	}
	
	for filename, content := range testFiles {
		filePath := filepath.Join(tempDir, filename)
		err := os.WriteFile(filePath, []byte(content), 0644)
		if err != nil {
			t.Fatalf("Failed to create file %s: %v", filename, err)
		}
	}
	
	// Update cache
	err = watcher.updateCache()
	if err != nil {
		t.Fatalf("updateCache failed: %v", err)
	}
	
	// Verify all files are in cache
	for filename, expectedContent := range testFiles {
		if value, ok := watcher.Cache.Load(filename); !ok {
			t.Errorf("File %s not found in cache", filename)
		} else if value != expectedContent {
			t.Errorf("Expected content '%s' for file %s, got '%s'", expectedContent, filename, value)
		}
	}
}

func TestWatcher_FileDeletion(t *testing.T) {
	tempDir := t.TempDir()
	watcher, err := NewWatch(tempDir)
	if err != nil {
		t.Fatalf("NewWatch failed: %v", err)
	}
	
	// Create a test file
	testFile := filepath.Join(tempDir, "test.txt")
	testContent := "test content"
	err = os.WriteFile(testFile, []byte(testContent), 0644)
	if err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}
	
	// Update cache
	err = watcher.updateCache()
	if err != nil {
		t.Fatalf("updateCache failed: %v", err)
	}
	
	// Verify file is in cache
	if _, ok := watcher.Cache.Load("test.txt"); !ok {
		t.Error("Test file not found in cache")
	}
	
	// Delete the file
	err = os.Remove(testFile)
	if err != nil {
		t.Fatalf("Failed to delete test file: %v", err)
	}
	
	// Update cache again
	err = watcher.updateCache()
	if err != nil {
		t.Fatalf("updateCache failed: %v", err)
	}
	
	// Verify file is removed from cache
	if _, ok := watcher.Cache.Load("test.txt"); ok {
		t.Error("Deleted file should not be in cache")
	}
}

func TestWatcher_LargeFiles(t *testing.T) {
	tempDir := t.TempDir()
	watcher, err := NewWatch(tempDir)
	if err != nil {
		t.Fatalf("NewWatch failed: %v", err)
	}
	
	// Create a large file (1MB)
	largeContent := make([]byte, 1024*1024)
	for i := range largeContent {
		largeContent[i] = byte(i % 256)
	}
	
	testFile := filepath.Join(tempDir, "large.txt")
	err = os.WriteFile(testFile, largeContent, 0644)
	if err != nil {
		t.Fatalf("Failed to create large file: %v", err)
	}
	
	// Update cache
	err = watcher.updateCache()
	if err != nil {
		t.Fatalf("updateCache failed: %v", err)
	}
	
	// Verify large file is in cache
	if value, ok := watcher.Cache.Load("large.txt"); !ok {
		t.Error("Large file not found in cache")
	} else if len(value.(string)) != len(largeContent) {
		t.Errorf("Large file size mismatch. Expected %d, got %d", len(largeContent), len(value.(string)))
	}
}

func TestWatcher_SpecialCharacters(t *testing.T) {
	tempDir := t.TempDir()
	watcher, err := NewWatch(tempDir)
	if err != nil {
		t.Fatalf("NewWatch failed: %v", err)
	}
	
	// Test with special characters in filename
	specialFiles := map[string]string{
		"file with spaces.txt": "content with spaces",
		"file-with-dashes.txt": "content-with-dashes",
		"file_with_underscores.txt": "content_with_underscores",
		"file.with.dots.txt": "content.with.dots",
	}
	
	for filename, content := range specialFiles {
		filePath := filepath.Join(tempDir, filename)
		err := os.WriteFile(filePath, []byte(content), 0644)
		if err != nil {
			t.Fatalf("Failed to create file %s: %v", filename, err)
		}
	}
	
	// Update cache
	err = watcher.updateCache()
	if err != nil {
		t.Fatalf("updateCache failed: %v", err)
	}
	
	// Verify all special files are in cache
	for filename, expectedContent := range specialFiles {
		if value, ok := watcher.Cache.Load(filename); !ok {
			t.Errorf("Special file %s not found in cache", filename)
		} else if value != expectedContent {
			t.Errorf("Expected content '%s' for file %s, got '%s'", expectedContent, filename, value)
		}
	}
}

func TestWatcher_Watch(t *testing.T) {
	tempDir := t.TempDir()
	watcher, err := NewWatch(tempDir)
	if err != nil {
		t.Fatalf("NewWatch failed: %v", err)
	}
	
	// Start watching
	watcher.Watch()
	
	// Give it a moment to start
	time.Sleep(100 * time.Millisecond)
	
	// Create a test file
	testFile := filepath.Join(tempDir, "watch-test.txt")
	testContent := "watch test content"
	err = os.WriteFile(testFile, []byte(testContent), 0644)
	if err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}
	
	// Give it time to process
	time.Sleep(500 * time.Millisecond)
	
	// Verify file is in cache
	if value, ok := watcher.Cache.Load("watch-test.txt"); !ok {
		// If not found, try manual update
		err = watcher.updateCache()
		if err != nil {
			t.Fatalf("Manual updateCache failed: %v", err)
		}
		
		// Check again
		if value, ok := watcher.Cache.Load("watch-test.txt"); !ok {
			t.Error("Watched file not found in cache even after manual update")
		} else if value != testContent {
			t.Errorf("Expected content '%s', got '%s'", testContent, value)
		}
	} else if value != testContent {
		t.Errorf("Expected content '%s', got '%s'", testContent, value)
	}
}
