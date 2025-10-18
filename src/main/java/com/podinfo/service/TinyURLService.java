package com.podinfo.service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;

/**
 * TinyURLService provides URL shortening and expansion functionality.
 * Thread-safe implementation using concurrent data structures.
 */
public class TinyURLService {
    private final Map<String, String> shortToLong;
    private final Map<String, String> longToShort;
    private final AtomicLong counter;
    private static final String BASE_URL = "https://short.ly/";

    /**
     * Constructor initializing the URL mapping storage.
     */
    public TinyURLService() {
        this.shortToLong = new ConcurrentHashMap<>();
        this.longToShort = new ConcurrentHashMap<>();
        this.counter = new AtomicLong(0);
    }

    /**
     * Shorten a long URL to a compact representation.
     *
     * @param longURL The original long URL
     * @return The shortened URL
     * @throws IllegalArgumentException if longURL is null or empty
     */
    public String shortenURL(String longURL) {
        if (longURL == null || longURL.isEmpty()) {
            throw new IllegalArgumentException("URL cannot be null or empty");
        }

        // Check if URL already shortened
        if (longToShort.containsKey(longURL)) {
            return longToShort.get(longURL);
        }

        // Generate short code using counter and hash
        String shortCode = generateShortCode(longURL);
        String shortURL = BASE_URL + shortCode;

        // Store bidirectional mapping
        shortToLong.put(shortCode, longURL);
        longToShort.put(longURL, shortURL);

        return shortURL;
    }

    /**
     * Expand a shortened URL back to its original form.
     *
     * @param shortURL The shortened URL
     * @return The original long URL
     * @throws IllegalArgumentException if shortURL is null, empty, or not found
     */
    public String expandURL(String shortURL) {
        if (shortURL == null || shortURL.isEmpty()) {
            throw new IllegalArgumentException("Short URL cannot be null or empty");
        }

        if (!shortURL.startsWith(BASE_URL)) {
            throw new IllegalArgumentException("Invalid short URL format");
        }

        String shortCode = shortURL.substring(BASE_URL.length());
        String longURL = shortToLong.get(shortCode);

        if (longURL == null) {
            throw new IllegalArgumentException("Short URL not found");
        }

        return longURL;
    }

    /**
     * Generate a short code for the URL using counter and hash.
     *
     * @param longURL The long URL to encode
     * @return A short code
     */
    private String generateShortCode(String longURL) {
        try {
            long id = counter.getAndIncrement();
            String toHash = longURL + id;

            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] hashBytes = md.digest(toHash.getBytes());
            String encoded = Base64.getUrlEncoder().encodeToString(hashBytes);

            // Take first 8 characters for short code
            return encoded.substring(0, Math.min(8, encoded.length()));
        } catch (NoSuchAlgorithmException e) {
            // Fallback to simple base conversion
            long id = counter.get();
            return Long.toString(id, 36);
        }
    }

    /**
     * Get the total number of URLs shortened.
     *
     * @return Number of unique shortened URLs
     */
    public int getUrlCount() {
        return shortToLong.size();
    }

    /**
     * Clear all URL mappings.
     */
    public void clear() {
        shortToLong.clear();
        longToShort.clear();
        counter.set(0);
    }

    /**
     * Check if a URL has been shortened.
     *
     * @param longURL The URL to check
     * @return true if URL has been shortened, false otherwise
     */
    public boolean hasURL(String longURL) {
        return longToShort.containsKey(longURL);
    }
}
