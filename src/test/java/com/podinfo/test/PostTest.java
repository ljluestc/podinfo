package com.podinfo.test;

import com.podinfo.model.Post;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

public class PostTest {

    @Test
    @DisplayName("Test Post creation with valid data")
    void testPostCreation() {
        Instant now = Instant.now();
        Post post = new Post("id123", "Test Title", "Test Content", "testuser", now);

        assertEquals("id123", post.getId());
        assertEquals("Test Title", post.getTitle());
        assertEquals("Test Content", post.getContent());
        assertEquals("testuser", post.getAuthor());
        assertEquals(now, post.getTimestamp());
    }

    @ParameterizedTest
    @NullAndEmptySource
    @DisplayName("Test Post creation with invalid ID")
    void testPostCreationInvalidId(String id) {
        Instant now = Instant.now();
        assertThrows(IllegalArgumentException.class, () -> {
            new Post(id, "Title", "Content", "author", now);
        });
    }

    @ParameterizedTest
    @NullAndEmptySource
    @DisplayName("Test Post creation with invalid title")
    void testPostCreationInvalidTitle(String title) {
        Instant now = Instant.now();
        assertThrows(IllegalArgumentException.class, () -> {
            new Post("id123", title, "Content", "author", now);
        });
    }

    @Test
    @DisplayName("Test Post creation with null content")
    void testPostCreationNullContent() {
        Instant now = Instant.now();
        assertThrows(IllegalArgumentException.class, () -> {
            new Post("id123", "Title", null, "author", now);
        });
    }

    @Test
    @DisplayName("Test Post creation with empty content is valid")
    void testPostCreationEmptyContent() {
        Instant now = Instant.now();
        Post post = new Post("id123", "Title", "", "author", now);
        assertEquals("", post.getContent());
    }

    @ParameterizedTest
    @NullAndEmptySource
    @DisplayName("Test Post creation with invalid author")
    void testPostCreationInvalidAuthor(String author) {
        Instant now = Instant.now();
        assertThrows(IllegalArgumentException.class, () -> {
            new Post("id123", "Title", "Content", author, now);
        });
    }

    @Test
    @DisplayName("Test Post creation with null timestamp")
    void testPostCreationNullTimestamp() {
        assertThrows(IllegalArgumentException.class, () -> {
            new Post("id123", "Title", "Content", "author", null);
        });
    }

    @Test
    @DisplayName("Test Post equals with same instance")
    void testEqualsSameInstance() {
        Instant now = Instant.now();
        Post post = new Post("id123", "Title", "Content", "author", now);
        assertEquals(post, post);
    }

    @Test
    @DisplayName("Test Post equals with same ID")
    void testEqualsSameId() {
        Instant now = Instant.now();
        Post post1 = new Post("id123", "Title1", "Content1", "author1", now);
        Post post2 = new Post("id123", "Title2", "Content2", "author2", now);
        assertEquals(post1, post2);
    }

    @Test
    @DisplayName("Test Post equals with different ID")
    void testEqualsDifferentId() {
        Instant now = Instant.now();
        Post post1 = new Post("id123", "Title", "Content", "author", now);
        Post post2 = new Post("id456", "Title", "Content", "author", now);
        assertNotEquals(post1, post2);
    }

    @Test
    @DisplayName("Test Post equals with null")
    void testEqualsNull() {
        Instant now = Instant.now();
        Post post = new Post("id123", "Title", "Content", "author", now);
        assertNotEquals(null, post);
    }

    @Test
    @DisplayName("Test Post equals with different class")
    void testEqualsDifferentClass() {
        Instant now = Instant.now();
        Post post = new Post("id123", "Title", "Content", "author", now);
        assertNotEquals(post, "not a post");
    }

    @Test
    @DisplayName("Test Post hashCode consistency")
    void testHashCodeConsistency() {
        Instant now = Instant.now();
        Post post = new Post("id123", "Title", "Content", "author", now);
        int hash1 = post.hashCode();
        int hash2 = post.hashCode();
        assertEquals(hash1, hash2);
    }

    @Test
    @DisplayName("Test Post hashCode with same ID")
    void testHashCodeSameId() {
        Instant now = Instant.now();
        Post post1 = new Post("id123", "Title1", "Content1", "author1", now);
        Post post2 = new Post("id123", "Title2", "Content2", "author2", now);
        assertEquals(post1.hashCode(), post2.hashCode());
    }

    @Test
    @DisplayName("Test Post toString contains ID")
    void testToStringContainsId() {
        Instant now = Instant.now();
        Post post = new Post("id123", "Title", "Content", "author", now);
        String toString = post.toString();
        assertTrue(toString.contains("id123"));
        assertTrue(toString.contains("Title"));
        assertTrue(toString.contains("author"));
    }

    @Test
    @DisplayName("Test Post toString format")
    void testToStringFormat() {
        Instant now = Instant.now();
        Post post = new Post("id123", "My Title", "Content", "john", now);
        String toString = post.toString();
        assertTrue(toString.startsWith("Post{"));
        assertTrue(toString.contains("id='id123'"));
        assertTrue(toString.contains("title='My Title'"));
        assertTrue(toString.contains("author='john'"));
    }

    @Test
    @DisplayName("Test Post immutability - getId returns same value")
    void testImmutabilityGetId() {
        Instant now = Instant.now();
        Post post = new Post("id123", "Title", "Content", "author", now);
        String id1 = post.getId();
        String id2 = post.getId();
        assertSame(id1, id2);
    }

    @Test
    @DisplayName("Test Post with special characters in content")
    void testPostWithSpecialCharacters() {
        Instant now = Instant.now();
        String specialContent = "Content with <html> & \"quotes\" and 'apostrophes'";
        Post post = new Post("id123", "Title", specialContent, "author", now);
        assertEquals(specialContent, post.getContent());
    }

    @Test
    @DisplayName("Test Post with very long content")
    void testPostWithLongContent() {
        Instant now = Instant.now();
        StringBuilder longContent = new StringBuilder();
        for (int i = 0; i < 10000; i++) {
            longContent.append("x");
        }
        Post post = new Post("id123", "Title", longContent.toString(), "author", now);
        assertEquals(10000, post.getContent().length());
    }
}
