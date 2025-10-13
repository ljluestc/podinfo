package signals

import (
	"testing"
)

func TestSetupSignalHandler(t *testing.T) {
	// Test that SetupSignalHandler returns a channel
	stopCh := SetupSignalHandler()
	if stopCh == nil {
		t.Error("SetupSignalHandler returned nil channel")
	}
	
	// Test that the channel is readable
	select {
	case <-stopCh:
		// Channel is closed, which is expected behavior
	default:
		// Channel is not closed yet, which is also expected
	}
}

func TestSetupSignalHandlerPanic(t *testing.T) {
	// Test that calling SetupSignalHandler twice panics
	defer func() {
		if r := recover(); r == nil {
			t.Error("Expected panic when calling SetupSignalHandler twice")
		}
	}()
	
	// First call should succeed
	SetupSignalHandler()
	
	// Second call should panic
	SetupSignalHandler()
}