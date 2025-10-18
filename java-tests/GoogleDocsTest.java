package com.podinfo.test;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.RepeatedTest;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.api.parallel.Execution;
import org.junit.jupiter.api.parallel.ExecutionMode;
import static org.junit.jupiter.api.Assertions.*;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.stream.IntStream;

@Execution(ExecutionMode.CONCURRENT)
public class GoogleDocsTest {
    private GoogleDocsService service;
    
    @BeforeEach
    void setUp() {
        service = new GoogleDocsService();
    }
    
    @Nested
    @DisplayName("Document Creation Tests")
    class DocumentCreationTests {
        
        @Test
        @DisplayName("Test document creation with valid data")
        void testCreateDocument() {
            Document doc = service.createDocument("Test Document", "user123");
            assertNotNull(doc);
            assertEquals("Test Document", doc.getTitle());
            assertEquals("user123", doc.getAuthor());
            assertNotNull(doc.getId());
            assertNotNull(doc.getCreatedAt());
        }
        
        @Test
        @DisplayName("Test document creation with empty title")
        void testCreateDocumentWithEmptyTitle() {
            Document doc = service.createDocument("", "user123");
            assertNotNull(doc);
            assertEquals("", doc.getTitle());
            assertEquals("user123", doc.getAuthor());
        }
        
        @Test
        @DisplayName("Test document creation with null author")
        void testCreateDocumentWithNullAuthor() {
            assertThrows(IllegalArgumentException.class, () -> {
                service.createDocument("Test Document", null);
            });
        }
    }
    
    @Nested
    @DisplayName("Document Update Tests")
    class DocumentUpdateTests {
        
        @Test
        @DisplayName("Test document content update")
        void testUpdateDocument() {
            Document doc = service.createDocument("Test Document", "user123");
            String newContent = "Updated content";
            
            service.updateDocument(doc.getId(), newContent);
            Document updatedDoc = service.getDocument(doc.getId());
            
            assertEquals(newContent, updatedDoc.getContent());
            assertTrue(updatedDoc.getUpdatedAt().isAfter(doc.getUpdatedAt()));
        }
        
        @Test
        @DisplayName("Test document update with non-existent ID")
        void testUpdateNonExistentDocument() {
            assertThrows(DocumentNotFoundException.class, () -> {
                service.updateDocument("non-existent-id", "content");
            });
        }
    }
    
    @Nested
    @DisplayName("Document Retrieval Tests")
    class DocumentRetrievalTests {
        
        @Test
        @DisplayName("Test document retrieval by ID")
        void testGetDocument() {
            Document doc = service.createDocument("Test Document", "user123");
            Document retrievedDoc = service.getDocument(doc.getId());
            
            assertEquals(doc.getId(), retrievedDoc.getId());
            assertEquals(doc.getTitle(), retrievedDoc.getTitle());
            assertEquals(doc.getAuthor(), retrievedDoc.getAuthor());
        }
        
        @Test
        @DisplayName("Test document retrieval with non-existent ID")
        void testGetNonExistentDocument() {
            assertThrows(DocumentNotFoundException.class, () -> {
                service.getDocument("non-existent-id");
            });
        }
    }
    
    @Nested
    @DisplayName("Collaboration Tests")
    class CollaborationTests {
        
        @Test
        @DisplayName("Test document sharing")
        void testShareDocument() {
            Document doc = service.createDocument("Test Document", "user123");
            service.shareDocument(doc.getId(), "user456", Permission.READ);
            
            List<Document> sharedDocs = service.getSharedDocuments("user456");
            assertTrue(sharedDocs.stream().anyMatch(d -> d.getId().equals(doc.getId())));
        }
        
        @Test
        @DisplayName("Test concurrent document editing")
        @Timeout(value = 5, unit = TimeUnit.SECONDS)
        void testConcurrentEditing() {
            Document doc = service.createDocument("Test Document", "user123");
            
            // Simulate concurrent editing
            CompletableFuture<Void> future1 = CompletableFuture.runAsync(() -> {
                service.updateDocument(doc.getId(), "Content from user 1");
            });
            
            CompletableFuture<Void> future2 = CompletableFuture.runAsync(() -> {
                service.updateDocument(doc.getId(), "Content from user 2");
            });
            
            CompletableFuture.allOf(future1, future2).join();
            
            Document updatedDoc = service.getDocument(doc.getId());
            assertNotNull(updatedDoc.getContent());
        }
    }
    
    @Nested
    @DisplayName("Performance Tests")
    class PerformanceTests {
        
        @RepeatedTest(10)
        @DisplayName("Test document creation performance")
        void testDocumentCreationPerformance() {
            long startTime = System.currentTimeMillis();
            service.createDocument("Performance Test Document", "user123");
            long endTime = System.currentTimeMillis();
            
            assertTrue(endTime - startTime < 100, "Document creation should be fast");
        }
        
        @Test
        @DisplayName("Test bulk document operations")
        void testBulkDocumentOperations() {
            long startTime = System.currentTimeMillis();
            
            IntStream.range(0, 100).forEach(i -> {
                service.createDocument("Bulk Document " + i, "user123");
            });
            
            long endTime = System.currentTimeMillis();
            assertTrue(endTime - startTime < 5000, "Bulk operations should complete within 5 seconds");
        }
    }
    
    @Nested
    @DisplayName("Edge Case Tests")
    class EdgeCaseTests {
        
        @Test
        @DisplayName("Test very long document content")
        void testVeryLongContent() {
            Document doc = service.createDocument("Long Content Test", "user123");
            String longContent = "A".repeat(100000);
            
            service.updateDocument(doc.getId(), longContent);
            Document updatedDoc = service.getDocument(doc.getId());
            
            assertEquals(longContent, updatedDoc.getContent());
        }
        
        @Test
        @DisplayName("Test special characters in content")
        void testSpecialCharacters() {
            Document doc = service.createDocument("Special Chars Test", "user123");
            String specialContent = "Special chars: !@#$%^&*()_+-=[]{}|;':\",./<>?";
            
            service.updateDocument(doc.getId(), specialContent);
            Document updatedDoc = service.getDocument(doc.getId());
            
            assertEquals(specialContent, updatedDoc.getContent());
        }
        
        @Test
        @DisplayName("Test unicode content")
        void testUnicodeContent() {
            Document doc = service.createDocument("Unicode Test", "user123");
            String unicodeContent = "Unicode: 你好世界 🌍 日本語 한국어";
            
            service.updateDocument(doc.getId(), unicodeContent);
            Document updatedDoc = service.getDocument(doc.getId());
            
            assertEquals(unicodeContent, updatedDoc.getContent());
        }
    }
}

