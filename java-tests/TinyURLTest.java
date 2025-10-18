package com.podinfo.test;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import static org.junit.jupiter.api.Assertions.*;

public class TinyURLTest {
    private TinyURLService service;
    
    @BeforeEach
    void setUp() {
        service = new TinyURLService();
    }
    
    @Test
    @DisplayName("Test URL shortening functionality")
    void testShortenURL() {
        String longURL = "https://example.com/very/long/url";
        String shortURL = service.shortenURL(longURL);
        assertNotNull(shortURL);
        assertTrue(shortURL.length() < longURL.length());
    }
    
    @Test
    @DisplayName("Test URL expansion functionality")
    void testExpandURL() {
        String longURL = "https://example.com/very/long/url";
        String shortURL = service.shortenURL(longURL);
        String expandedURL = service.expandURL(shortURL);
        assertEquals(longURL, expandedURL);
    }
    
    @Test
    @DisplayName("Test concurrent URL operations")
    void testConcurrentOperations() throws InterruptedException {
        int numThreads = 10;
        Thread[] threads = new Thread[numThreads];
        
        for (int i = 0; i < numThreads; i++) {
            final int threadId = i;
            threads[i] = new Thread(() -> {
                String longURL = "https://example.com/url/" + threadId;
                String shortURL = service.shortenURL(longURL);
                String expandedURL = service.expandURL(shortURL);
                assertEquals(longURL, expandedURL);
            });
        }
        
        for (Thread thread : threads) {
            thread.start();
        }
        
        for (Thread thread : threads) {
            thread.join();
        }
    }
    
    @Test
    @DisplayName("Test performance with large number of URLs")
    void testPerformance() {
        long startTime = System.currentTimeMillis();
        
        for (int i = 0; i < 1000; i++) {
            String longURL = "https://example.com/url/" + i;
            String shortURL = service.shortenURL(longURL);
            service.expandURL(shortURL);
        }
        
        long endTime = System.currentTimeMillis();
        long duration = endTime - startTime;
        
        assertTrue(duration < 5000, "Performance test should complete within 5 seconds");
    }
}
