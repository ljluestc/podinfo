package com.podinfo.test;

import com.podinfo.service.TinyURLService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import static org.junit.jupiter.api.Assertions.*;

public class TinyURLServiceTest {
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
        assertTrue(shortURL.startsWith("https://short.ly/"));
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
    @DisplayName("Test shortening same URL twice returns same short URL")
    void testShortenSameURLTwice() {
        String longURL = "https://example.com/test";
        String shortURL1 = service.shortenURL(longURL);
        String shortURL2 = service.shortenURL(longURL);
        assertEquals(shortURL1, shortURL2);
    }

    @ParameterizedTest
    @NullAndEmptySource
    @DisplayName("Test shorten URL with null or empty input")
    void testShortenURLInvalidInput(String url) {
        assertThrows(IllegalArgumentException.class, () -> {
            service.shortenURL(url);
        });
    }

    @ParameterizedTest
    @NullAndEmptySource
    @DisplayName("Test expand URL with null or empty input")
    void testExpandURLInvalidInput(String url) {
        assertThrows(IllegalArgumentException.class, () -> {
            service.expandURL(url);
        });
    }

    @Test
    @DisplayName("Test expand URL with invalid format")
    void testExpandURLInvalidFormat() {
        assertThrows(IllegalArgumentException.class, () -> {
            service.expandURL("https://invalid.com/abc");
        });
    }

    @Test
    @DisplayName("Test expand URL not found")
    void testExpandURLNotFound() {
        assertThrows(IllegalArgumentException.class, () -> {
            service.expandURL("https://short.ly/notfound");
        });
    }

    @Test
    @DisplayName("Test concurrent URL operations")
    void testConcurrentOperations() throws InterruptedException {
        int numThreads = 10;
        Thread[] threads = new Thread[numThreads];
        final String[] results = new String[numThreads];

        for (int i = 0; i < numThreads; i++) {
            final int threadId = i;
            threads[i] = new Thread(() -> {
                String longURL = "https://example.com/url/" + threadId;
                String shortURL = service.shortenURL(longURL);
                String expandedURL = service.expandURL(shortURL);
                results[threadId] = expandedURL;
            });
        }

        for (Thread thread : threads) {
            thread.start();
        }

        for (Thread thread : threads) {
            thread.join();
        }

        // Verify all operations completed correctly
        for (int i = 0; i < numThreads; i++) {
            assertEquals("https://example.com/url/" + i, results[i]);
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

    @Test
    @DisplayName("Test getUrlCount")
    void testGetUrlCount() {
        assertEquals(0, service.getUrlCount());
        service.shortenURL("https://example.com/url1");
        assertEquals(1, service.getUrlCount());
        service.shortenURL("https://example.com/url2");
        assertEquals(2, service.getUrlCount());
    }

    @Test
    @DisplayName("Test hasURL")
    void testHasURL() {
        String longURL = "https://example.com/test";
        assertFalse(service.hasURL(longURL));
        service.shortenURL(longURL);
        assertTrue(service.hasURL(longURL));
    }

    @Test
    @DisplayName("Test clear functionality")
    void testClear() {
        service.shortenURL("https://example.com/url1");
        service.shortenURL("https://example.com/url2");
        assertEquals(2, service.getUrlCount());
        service.clear();
        assertEquals(0, service.getUrlCount());
    }

    @Test
    @DisplayName("Test multiple different URLs")
    void testMultipleDifferentURLs() {
        String url1 = "https://example.com/url1";
        String url2 = "https://example.com/url2";
        String url3 = "https://example.com/url3";

        String short1 = service.shortenURL(url1);
        String short2 = service.shortenURL(url2);
        String short3 = service.shortenURL(url3);

        assertNotEquals(short1, short2);
        assertNotEquals(short2, short3);
        assertNotEquals(short1, short3);

        assertEquals(url1, service.expandURL(short1));
        assertEquals(url2, service.expandURL(short2));
        assertEquals(url3, service.expandURL(short3));
    }
}
