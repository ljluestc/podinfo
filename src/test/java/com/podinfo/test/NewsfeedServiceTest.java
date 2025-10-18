package com.podinfo.test;

import com.podinfo.model.Post;
import com.podinfo.service.NewsfeedService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

public class NewsfeedServiceTest {
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
        assertNotNull(post.getId());
        assertNotNull(post.getTimestamp());
    }

    @ParameterizedTest
    @NullAndEmptySource
    @DisplayName("Test create post with invalid title")
    void testCreatePostInvalidTitle(String title) {
        assertThrows(IllegalArgumentException.class, () -> {
            service.createPost(title, "Content", "author");
        });
    }

    @Test
    @DisplayName("Test create post with null content")
    void testCreatePostNullContent() {
        assertThrows(IllegalArgumentException.class, () -> {
            service.createPost("Title", null, "author");
        });
    }

    @ParameterizedTest
    @NullAndEmptySource
    @DisplayName("Test create post with invalid author")
    void testCreatePostInvalidAuthor(String author) {
        assertThrows(IllegalArgumentException.class, () -> {
            service.createPost("Title", "Content", author);
        });
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
    @DisplayName("Test feed retrieval with limit")
    void testGetFeedWithLimit() {
        service.createPost("Post 1", "Content 1", "user1");
        service.createPost("Post 2", "Content 2", "user2");
        service.createPost("Post 3", "Content 3", "user3");

        List<Post> feed = service.getFeed(2);
        assertEquals(2, feed.size());
    }

    @ParameterizedTest
    @ValueSource(ints = {0, -1, -10})
    @DisplayName("Test get feed with invalid limit")
    void testGetFeedInvalidLimit(int limit) {
        assertThrows(IllegalArgumentException.class, () -> {
            service.getFeed(limit);
        });
    }

    @Test
    @DisplayName("Test feed is sorted by timestamp descending")
    void testFeedSortedByTimestamp() throws InterruptedException {
        Post post1 = service.createPost("Post 1", "Content 1", "user1");
        Thread.sleep(10); // Ensure different timestamps
        Post post2 = service.createPost("Post 2", "Content 2", "user2");
        Thread.sleep(10);
        Post post3 = service.createPost("Post 3", "Content 3", "user3");

        List<Post> feed = service.getFeed(10);
        assertEquals(post3.getId(), feed.get(0).getId());
        assertEquals(post2.getId(), feed.get(1).getId());
        assertEquals(post1.getId(), feed.get(2).getId());
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

    @Test
    @DisplayName("Test get post by ID")
    void testGetPost() {
        Post created = service.createPost("Test", "Content", "author");
        Post retrieved = service.getPost(created.getId());
        assertNotNull(retrieved);
        assertEquals(created.getId(), retrieved.getId());
    }

    @Test
    @DisplayName("Test get non-existent post")
    void testGetNonExistentPost() {
        Post post = service.getPost("non-existent-id");
        assertNull(post);
    }

    @ParameterizedTest
    @NullAndEmptySource
    @DisplayName("Test get post with invalid ID")
    void testGetPostInvalidId(String id) {
        assertThrows(IllegalArgumentException.class, () -> {
            service.getPost(id);
        });
    }

    @Test
    @DisplayName("Test delete post")
    void testDeletePost() {
        Post post = service.createPost("Test", "Content", "author");
        assertTrue(service.deletePost(post.getId()));
        assertNull(service.getPost(post.getId()));
    }

    @Test
    @DisplayName("Test delete non-existent post")
    void testDeleteNonExistentPost() {
        assertFalse(service.deletePost("non-existent-id"));
    }

    @ParameterizedTest
    @NullAndEmptySource
    @DisplayName("Test delete post with invalid ID")
    void testDeletePostInvalidId(String id) {
        assertThrows(IllegalArgumentException.class, () -> {
            service.deletePost(id);
        });
    }

    @Test
    @DisplayName("Test get posts by author")
    void testGetPostsByAuthor() {
        service.createPost("Post 1", "Content 1", "user1");
        service.createPost("Post 2", "Content 2", "user1");
        service.createPost("Post 3", "Content 3", "user2");

        List<Post> user1Posts = service.getPostsByAuthor("user1", 10);
        assertEquals(2, user1Posts.size());
    }

    @Test
    @DisplayName("Test get posts by author with limit")
    void testGetPostsByAuthorWithLimit() {
        service.createPost("Post 1", "Content 1", "user1");
        service.createPost("Post 2", "Content 2", "user1");
        service.createPost("Post 3", "Content 3", "user1");

        List<Post> posts = service.getPostsByAuthor("user1", 2);
        assertEquals(2, posts.size());
    }

    @ParameterizedTest
    @NullAndEmptySource
    @DisplayName("Test get posts by invalid author")
    void testGetPostsByInvalidAuthor(String author) {
        assertThrows(IllegalArgumentException.class, () -> {
            service.getPostsByAuthor(author, 10);
        });
    }

    @ParameterizedTest
    @ValueSource(ints = {0, -1, -10})
    @DisplayName("Test get posts by author with invalid limit")
    void testGetPostsByAuthorInvalidLimit(int limit) {
        assertThrows(IllegalArgumentException.class, () -> {
            service.getPostsByAuthor("user1", limit);
        });
    }

    @Test
    @DisplayName("Test get post count")
    void testGetPostCount() {
        assertEquals(0, service.getPostCount());
        service.createPost("Post 1", "Content 1", "user1");
        assertEquals(1, service.getPostCount());
        service.createPost("Post 2", "Content 2", "user2");
        assertEquals(2, service.getPostCount());
    }

    @Test
    @DisplayName("Test clear functionality")
    void testClear() {
        service.createPost("Post 1", "Content 1", "user1");
        service.createPost("Post 2", "Content 2", "user2");
        assertEquals(2, service.getPostCount());
        service.clear();
        assertEquals(0, service.getPostCount());
    }

    @Test
    @DisplayName("Test has post")
    void testHasPost() {
        Post post = service.createPost("Test", "Content", "author");
        assertTrue(service.hasPost(post.getId()));
        assertFalse(service.hasPost("non-existent-id"));
        assertFalse(service.hasPost(null));
    }
}
