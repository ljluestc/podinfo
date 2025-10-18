package com.podinfo.test;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import static org.junit.jupiter.api.Assertions.*;

public class LoadBalancerTest {
    private LoadBalancerService service;
    
    @BeforeEach
    void setUp() {
        String[] servers = {"server1", "server2", "server3"};
        service = new LoadBalancerService(servers);
    }
    
    @Test
    @DisplayName("Test round-robin load balancing")
    void testRoundRobin() {
        String server1 = service.getNextServer();
        String server2 = service.getNextServer();
        String server3 = service.getNextServer();
        String server4 = service.getNextServer();
        
        assertEquals("server1", server1);
        assertEquals("server2", server2);
        assertEquals("server3", server3);
        assertEquals("server1", server4); // Should cycle back
    }
    
    @Test
    @DisplayName("Test health check functionality")
    void testHealthCheck() {
        boolean isHealthy = service.healthCheck("server1");
        assertTrue(isHealthy);
    }
    
    @Test
    @DisplayName("Test concurrent load balancing")
    void testConcurrentLoadBalancing() throws InterruptedException {
        int numThreads = 10;
        Thread[] threads = new Thread[numThreads];
        String[] selectedServers = new String[numThreads];
        
        for (int i = 0; i < numThreads; i++) {
            final int threadId = i;
            threads[i] = new Thread(() -> {
                selectedServers[threadId] = service.getNextServer();
            });
        }
        
        for (Thread thread : threads) {
            thread.start();
        }
        
        for (Thread thread : threads) {
            thread.join();
        }
        
        // Verify all servers were selected
        boolean server1Selected = false, server2Selected = false, server3Selected = false;
        for (String server : selectedServers) {
            if ("server1".equals(server)) server1Selected = true;
            if ("server2".equals(server)) server2Selected = true;
            if ("server3".equals(server)) server3Selected = true;
        }
        
        assertTrue(server1Selected && server2Selected && server3Selected);
    }
}
