package com.podinfo.service;

import com.podinfo.model.Post;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.stream.Collectors;

/**
 * NewsfeedService manages creation and retrieval of newsfeed posts.
 * Thread-safe implementation using concurrent collections.
 */
public class NewsfeedService {
    private final ConcurrentMap<String, Post> posts;

    /**
     * Constructor initializing the newsfeed storage.
     */
    public NewsfeedService() {
        this.posts = new ConcurrentHashMap<>();
    }

    /**
     * Create a new post in the newsfeed.
     *
     * @param title Post title
     * @param content Post content
     * @param author Author username
     * @return The created Post object
     * @throws IllegalArgumentException if any parameter is null or empty
     */
    public Post createPost(String title, String content, String author) {
        if (title == null || title.isEmpty()) {
            throw new IllegalArgumentException("Title cannot be null or empty");
        }
        if (content == null) {
            throw new IllegalArgumentException("Content cannot be null");
        }
        if (author == null || author.isEmpty()) {
            throw new IllegalArgumentException("Author cannot be null or empty");
        }

        String id = UUID.randomUUID().toString();
        Instant timestamp = Instant.now();
        Post post = new Post(id, title, content, author, timestamp);

        posts.put(id, post);
        return post;
    }

    /**
     * Retrieve the newsfeed with most recent posts.
     *
     * @param limit Maximum number of posts to retrieve
     * @return List of posts sorted by timestamp (newest first)
     * @throws IllegalArgumentException if limit is less than 1
     */
    public List<Post> getFeed(int limit) {
        if (limit < 1) {
            throw new IllegalArgumentException("Limit must be at least 1");
        }

        return posts.values().stream()
                .sorted(Comparator.comparing(Post::getTimestamp).reversed())
                .limit(limit)
                .collect(Collectors.toList());
    }

    /**
     * Get a specific post by ID.
     *
     * @param id Post ID
     * @return The Post object, or null if not found
     */
    public Post getPost(String id) {
        if (id == null || id.isEmpty()) {
            throw new IllegalArgumentException("Post ID cannot be null or empty");
        }
        return posts.get(id);
    }

    /**
     * Delete a post from the newsfeed.
     *
     * @param id Post ID to delete
     * @return true if post was deleted, false if not found
     */
    public boolean deletePost(String id) {
        if (id == null || id.isEmpty()) {
            throw new IllegalArgumentException("Post ID cannot be null or empty");
        }
        return posts.remove(id) != null;
    }

    /**
     * Get posts by a specific author.
     *
     * @param author Author username
     * @param limit Maximum number of posts to retrieve
     * @return List of posts by the author
     */
    public List<Post> getPostsByAuthor(String author, int limit) {
        if (author == null || author.isEmpty()) {
            throw new IllegalArgumentException("Author cannot be null or empty");
        }
        if (limit < 1) {
            throw new IllegalArgumentException("Limit must be at least 1");
        }

        return posts.values().stream()
                .filter(post -> post.getAuthor().equals(author))
                .sorted(Comparator.comparing(Post::getTimestamp).reversed())
                .limit(limit)
                .collect(Collectors.toList());
    }

    /**
     * Get the total number of posts.
     *
     * @return Number of posts in the newsfeed
     */
    public int getPostCount() {
        return posts.size();
    }

    /**
     * Clear all posts from the newsfeed.
     */
    public void clear() {
        posts.clear();
    }

    /**
     * Check if a post exists.
     *
     * @param id Post ID
     * @return true if post exists, false otherwise
     */
    public boolean hasPost(String id) {
        return id != null && posts.containsKey(id);
    }
}
