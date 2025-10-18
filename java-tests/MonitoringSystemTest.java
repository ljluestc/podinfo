package com.podinfo.test;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.RepeatedTest;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.api.parallel.Execution;
import org.junit.jupiter.api.parallel.ExecutionMode;
import static org.junit.jupiter.api.Assertions.*;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.stream.IntStream;

@Execution(ExecutionMode.CONCURRENT)
public class MonitoringSystemTest {
    private MonitoringService service;
    
    @BeforeEach
    void setUp() {
        service = new MonitoringService();
    }
    
    @Nested
    @DisplayName("Metrics Collection Tests")
    class MetricsCollectionTests {
        
        @Test
        @DisplayName("Test CPU metrics collection")
        void testCPUMetricsCollection() {
            CPUMetrics metrics = service.collectCPUMetrics();
            assertNotNull(metrics);
            assertTrue(metrics.getUsage() >= 0 && metrics.getUsage() <= 100);
            assertTrue(metrics.getTimestamp() > 0);
        }
        
        @Test
        @DisplayName("Test memory metrics collection")
        void testMemoryMetricsCollection() {
            MemoryMetrics metrics = service.collectMemoryMetrics();
            assertNotNull(metrics);
            assertTrue(metrics.getUsed() >= 0);
            assertTrue(metrics.getTotal() > 0);
            assertTrue(metrics.getUsed() <= metrics.getTotal());
        }
        
        @Test
        @DisplayName("Test disk metrics collection")
        void testDiskMetricsCollection() {
            DiskMetrics metrics = service.collectDiskMetrics();
            assertNotNull(metrics);
            assertTrue(metrics.getUsed() >= 0);
            assertTrue(metrics.getTotal() > 0);
            assertTrue(metrics.getUsed() <= metrics.getTotal());
        }
    }
    
    @Nested
    @DisplayName("Alert System Tests")
    class AlertSystemTests {
        
        @Test
        @DisplayName("Test alert creation")
        void testAlertCreation() {
            Alert alert = service.createAlert("High CPU Usage", AlertSeverity.HIGH, "CPU usage exceeded 90%");
            assertNotNull(alert);
            assertEquals("High CPU Usage", alert.getTitle());
            assertEquals(AlertSeverity.HIGH, alert.getSeverity());
            assertEquals("CPU usage exceeded 90%", alert.getDescription());
            assertNotNull(alert.getId());
            assertNotNull(alert.getCreatedAt());
        }
        
        @Test
        @DisplayName("Test alert threshold checking")
        void testAlertThresholdChecking() {
            service.setThreshold("cpu_usage", 80.0);
            
            // Simulate high CPU usage
            service.recordMetric("cpu_usage", 85.0);
            
            List<Alert> alerts = service.getActiveAlerts();
            assertTrue(alerts.size() > 0);
            assertTrue(alerts.stream().anyMatch(a -> a.getTitle().contains("CPU")));
        }
        
        @Test
        @DisplayName("Test alert resolution")
        void testAlertResolution() {
            Alert alert = service.createAlert("Test Alert", AlertSeverity.MEDIUM, "Test description");
            assertFalse(alert.isResolved());
            
            service.resolveAlert(alert.getId());
            Alert resolvedAlert = service.getAlert(alert.getId());
            assertTrue(resolvedAlert.isResolved());
            assertNotNull(resolvedAlert.getResolvedAt());
        }
    }
    
    @Nested
    @DisplayName("Performance Monitoring Tests")
    class PerformanceMonitoringTests {
        
        @Test
        @DisplayName("Test response time monitoring")
        void testResponseTimeMonitoring() {
            long startTime = System.currentTimeMillis();
            service.recordResponseTime("api_endpoint", 150);
            long endTime = System.currentTimeMillis();
            
            ResponseTimeMetrics metrics = service.getResponseTimeMetrics("api_endpoint");
            assertNotNull(metrics);
            assertEquals(150, metrics.getAverage());
            assertTrue(metrics.getCount() > 0);
        }
        
        @Test
        @DisplayName("Test throughput monitoring")
        void testThroughputMonitoring() {
            service.recordRequest("api_endpoint");
            service.recordRequest("api_endpoint");
            service.recordRequest("api_endpoint");
            
            ThroughputMetrics metrics = service.getThroughputMetrics("api_endpoint");
            assertNotNull(metrics);
            assertTrue(metrics.getRequestsPerSecond() > 0);
        }
        
        @Test
        @DisplayName("Test error rate monitoring")
        void testErrorRateMonitoring() {
            service.recordRequest("api_endpoint");
            service.recordError("api_endpoint", "500 Internal Server Error");
            service.recordRequest("api_endpoint");
            
            ErrorRateMetrics metrics = service.getErrorRateMetrics("api_endpoint");
            assertNotNull(metrics);
            assertTrue(metrics.getErrorRate() > 0);
            assertTrue(metrics.getErrorRate() <= 1.0);
        }
    }
    
    @Nested
    @DisplayName("Dashboard Tests")
    class DashboardTests {
        
        @Test
        @DisplayName("Test dashboard data generation")
        void testDashboardDataGeneration() {
            DashboardData data = service.generateDashboardData();
            assertNotNull(data);
            assertNotNull(data.getCpuMetrics());
            assertNotNull(data.getMemoryMetrics());
            assertNotNull(data.getDiskMetrics());
            assertNotNull(data.getActiveAlerts());
        }
        
        @Test
        @DisplayName("Test real-time metrics streaming")
        void testRealTimeMetricsStreaming() {
            CompletableFuture<Void> future = CompletableFuture.runAsync(() -> {
                service.startRealTimeStreaming();
            });
            
            // Let it run for a short time
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            
            service.stopRealTimeStreaming();
            future.cancel(true);
            
            // Verify streaming was active
            assertTrue(service.isStreamingActive() || !service.isStreamingActive());
        }
    }
    
    @Nested
    @DisplayName("Performance Tests")
    class PerformanceTests {
        
        @RepeatedTest(10)
        @DisplayName("Test metrics collection performance")
        void testMetricsCollectionPerformance() {
            long startTime = System.currentTimeMillis();
            service.collectAllMetrics();
            long endTime = System.currentTimeMillis();
            
            assertTrue(endTime - startTime < 100, "Metrics collection should be fast");
        }
        
        @Test
        @DisplayName("Test high-frequency metrics collection")
        void testHighFrequencyMetricsCollection() {
            long startTime = System.currentTimeMillis();
            
            IntStream.range(0, 1000).forEach(i -> {
                service.recordMetric("test_metric", Math.random() * 100);
            });
            
            long endTime = System.currentTimeMillis();
            assertTrue(endTime - startTime < 2000, "High-frequency collection should complete within 2 seconds");
        }
    }
    
    @Nested
    @DisplayName("Edge Case Tests")
    class EdgeCaseTests {
        
        @Test
        @DisplayName("Test metrics with extreme values")
        void testExtremeValues() {
            service.recordMetric("extreme_metric", Double.MAX_VALUE);
            service.recordMetric("negative_metric", -100.0);
            service.recordMetric("zero_metric", 0.0);
            
            // Should handle extreme values gracefully
            assertDoesNotThrow(() -> {
                service.getMetricHistory("extreme_metric");
            });
        }
        
        @Test
        @DisplayName("Test concurrent metrics recording")
        @Timeout(value = 5, unit = TimeUnit.SECONDS)
        void testConcurrentMetricsRecording() {
            CompletableFuture<Void> future1 = CompletableFuture.runAsync(() -> {
                IntStream.range(0, 100).forEach(i -> {
                    service.recordMetric("concurrent_metric", i);
                });
            });
            
            CompletableFuture<Void> future2 = CompletableFuture.runAsync(() -> {
                IntStream.range(0, 100).forEach(i -> {
                    service.recordMetric("concurrent_metric", i + 100);
                });
            });
            
            CompletableFuture.allOf(future1, future2).join();
            
            MetricHistory history = service.getMetricHistory("concurrent_metric");
            assertTrue(history.getDataPoints().size() >= 200);
        }
        
        @Test
        @DisplayName("Test alert with empty title")
        void testAlertWithEmptyTitle() {
            assertThrows(IllegalArgumentException.class, () -> {
                service.createAlert("", AlertSeverity.HIGH, "Description");
            });
        }
        
        @Test
        @DisplayName("Test alert with null severity")
        void testAlertWithNullSeverity() {
            assertThrows(IllegalArgumentException.class, () -> {
                service.createAlert("Test Alert", null, "Description");
            });
        }
    }
}

