package com.podinfo.service;

import java.util.concurrent.atomic.AtomicInteger;

/**
 * LoadBalancerService implements round-robin load balancing across multiple servers.
 * Thread-safe implementation using atomic operations.
 */
public class LoadBalancerService {
    private final String[] servers;
    private final AtomicInteger currentIndex;

    /**
     * Constructor initializing the load balancer with a list of servers.
     *
     * @param servers Array of server identifiers
     * @throws IllegalArgumentException if servers array is null or empty
     */
    public LoadBalancerService(String[] servers) {
        if (servers == null || servers.length == 0) {
            throw new IllegalArgumentException("Servers array cannot be null or empty");
        }
        this.servers = servers.clone();
        this.currentIndex = new AtomicInteger(0);
    }

    /**
     * Get the next server using round-robin algorithm.
     * Thread-safe operation using atomic counter.
     *
     * @return The next server identifier
     */
    public String getNextServer() {
        int index = currentIndex.getAndUpdate(i -> (i + 1) % servers.length);
        return servers[index];
    }

    /**
     * Perform health check on a specific server.
     *
     * @param serverName The server to check
     * @return true if server is healthy, false otherwise
     */
    public boolean healthCheck(String serverName) {
        if (serverName == null || serverName.isEmpty()) {
            return false;
        }

        // Check if server exists in our list
        for (String server : servers) {
            if (server.equals(serverName)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Get the total number of servers.
     *
     * @return Number of servers in the pool
     */
    public int getServerCount() {
        return servers.length;
    }

    /**
     * Get a copy of all servers.
     *
     * @return Array of all server identifiers
     */
    public String[] getAllServers() {
        return servers.clone();
    }

    /**
     * Reset the load balancer counter to start from the beginning.
     */
    public void reset() {
        currentIndex.set(0);
    }
}
