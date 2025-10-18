package com.podinfo.test;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import static org.junit.jupiter.api.Assertions.*;
import java.util.List;

public class NewsfeedTest {
    private NewsfeedService service;
    
    @BeforeEach
    void setUp() {
        service = new NewsfeedService();
    }
    
    @Test
    @DisplayName("Test post creation")
    void testCreatePost() {
        Post post = service.createPost("Test Title", "Test Content", "testuser");
        assertNotNull(post);
        assertEquals("Test Title", post.getTitle());
        assertEquals("Test Content", post.getContent());
        assertEquals("testuser", post.getAuthor());
    }
    
    @Test
    @DisplayName("Test feed retrieval")
    void testGetFeed() {
        service.createPost("Post 1", "Content 1", "user1");
        service.createPost("Post 2", "Content 2", "user2");
        
        List<Post> feed = service.getFeed(10);
        assertEquals(2, feed.size());
    }
    
    @Test
    @DisplayName("Test concurrent post creation")
    void testConcurrentPostCreation() throws InterruptedException {
        int numThreads = 5;
        Thread[] threads = new Thread[numThreads];
        
        for (int i = 0; i < numThreads; i++) {
            final int threadId = i;
            threads[i] = new Thread(() -> {
                service.createPost("Post " + threadId, "Content " + threadId, "user" + threadId);
            });
        }
        
        for (Thread thread : threads) {
            thread.start();
        }
        
        for (Thread thread : threads) {
            thread.join();
        }
        
        List<Post> feed = service.getFeed(10);
        assertEquals(numThreads, feed.size());
    }
}
