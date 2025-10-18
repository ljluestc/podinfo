package com.podinfo.model;

import java.time.Instant;
import java.util.Objects;

/**
 * Post model representing a newsfeed post.
 * Immutable class with all fields final.
 */
public class Post {
    private final String id;
    private final String title;
    private final String content;
    private final String author;
    private final Instant timestamp;

    /**
     * Constructor for creating a new post.
     *
     * @param id Unique identifier
     * @param title Post title
     * @param content Post content
     * @param author Author username
     * @param timestamp Creation timestamp
     */
    public Post(String id, String title, String content, String author, Instant timestamp) {
        if (id == null || id.isEmpty()) {
            throw new IllegalArgumentException("Post ID cannot be null or empty");
        }
        if (title == null || title.isEmpty()) {
            throw new IllegalArgumentException("Post title cannot be null or empty");
        }
        if (content == null) {
            throw new IllegalArgumentException("Post content cannot be null");
        }
        if (author == null || author.isEmpty()) {
            throw new IllegalArgumentException("Post author cannot be null or empty");
        }
        if (timestamp == null) {
            throw new IllegalArgumentException("Post timestamp cannot be null");
        }

        this.id = id;
        this.title = title;
        this.content = content;
        this.author = author;
        this.timestamp = timestamp;
    }

    public String getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public String getContent() {
        return content;
    }

    public String getAuthor() {
        return author;
    }

    public Instant getTimestamp() {
        return timestamp;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Post post = (Post) o;
        return Objects.equals(id, post.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }

    @Override
    public String toString() {
        return "Post{" +
                "id='" + id + '\'' +
                ", title='" + title + '\'' +
                ", author='" + author + '\'' +
                ", timestamp=" + timestamp +
                '}';
    }
}
