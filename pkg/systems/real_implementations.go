package systems

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"sync"
	"time"
)

// TinyURL System Implementation
type TinyURLService struct {
	urls  map[string]string
	mutex sync.RWMutex
}

func NewTinyURLService() *TinyURLService {
	return &TinyURLService{
		urls: make(map[string]string),
	}
}

func (s *TinyURLService) ShortenURL(longURL string) (string, error) {
	// Generate short code
	bytes := make([]byte, 4)
	rand.Read(bytes)
	shortCode := hex.EncodeToString(bytes)

	// Store mapping with mutex protection
	s.mutex.Lock()
	s.urls[shortCode] = longURL
	s.mutex.Unlock()

	return fmt.Sprintf("https://tiny.url/%s", shortCode), nil
}

func (s *TinyURLService) ExpandURL(shortCode string) (string, error) {
	s.mutex.RLock()
	longURL, exists := s.urls[shortCode]
	s.mutex.RUnlock()

	if !exists {
		return "", fmt.Errorf("short code not found")
	}
	return longURL, nil
}

// Newsfeed System Implementation
type NewsfeedService struct {
	posts []Post
}

type Post struct {
	ID      string    `json:"id"`
	Title   string    `json:"title"`
	Content string    `json:"content"`
	Author  string    `json:"author"`
	Created time.Time `json:"created"`
}

func NewNewsfeedService() *NewsfeedService {
	return &NewsfeedService{
		posts: make([]Post, 0),
	}
}

func (s *NewsfeedService) CreatePost(title, content, author string) (*Post, error) {
	post := &Post{
		ID:      fmt.Sprintf("post_%d", time.Now().UnixNano()),
		Title:   title,
		Content: content,
		Author:  author,
		Created: time.Now(),
	}

	s.posts = append(s.posts, *post)
	return post, nil
}

func (s *NewsfeedService) GetFeed(limit int) ([]Post, error) {
	if limit > len(s.posts) {
		limit = len(s.posts)
	}

	// Return latest posts
	start := len(s.posts) - limit
	if start < 0 {
		start = 0
	}

	return s.posts[start:], nil
}

// Google Docs System Implementation
type GoogleDocsService struct {
	documents map[string]GoogleDoc
}

type GoogleDoc struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Content   string    `json:"content"`
	Owner     string    `json:"owner"`
	Created   time.Time `json:"created"`
	Modified  time.Time `json:"modified"`
	Collaborators []string `json:"collaborators"`
}

func NewGoogleDocsService() *GoogleDocsService {
	return &GoogleDocsService{
		documents: make(map[string]GoogleDoc),
	}
}

func (s *GoogleDocsService) CreateDocument(title, owner string) (*GoogleDoc, error) {
	doc := &GoogleDoc{
		ID:        fmt.Sprintf("doc_%d", time.Now().UnixNano()),
		Title:     title,
		Content:   "",
		Owner:     owner,
		Created:   time.Now(),
		Modified:  time.Now(),
		Collaborators: []string{owner},
	}

	s.documents[doc.ID] = *doc
	return doc, nil
}

func (s *GoogleDocsService) UpdateDocument(id, content string) error {
	doc, exists := s.documents[id]
	if !exists {
		return fmt.Errorf("document not found")
	}

	doc.Content = content
	doc.Modified = time.Now()
	s.documents[id] = doc

	return nil
}

func (s *GoogleDocsService) GetDocument(id string) (*GoogleDoc, error) {
	doc, exists := s.documents[id]
	if !exists {
		return nil, fmt.Errorf("document not found")
	}
	return &doc, nil
}

// Load Balancer System Implementation
type LoadBalancerService struct {
	servers []string
	current int
}

func NewLoadBalancerService(servers []string) *LoadBalancerService {
	return &LoadBalancerService{
		servers: servers,
		current: 0,
	}
}

func (s *LoadBalancerService) GetNextServer() string {
	if len(s.servers) == 0 {
		return ""
	}

	server := s.servers[s.current]
	s.current = (s.current + 1) % len(s.servers)
	return server
}

func (s *LoadBalancerService) HealthCheck(server string) bool {
	// Simulate health check
	return true
}

// Monitoring System Implementation
type MonitoringService struct {
	metrics map[string]float64
	alerts  []MonitoringAlert
}

type MonitoringAlert struct {
	ID       string    `json:"id"`
	Message  string    `json:"message"`
	Severity string    `json:"severity"`
	Time     time.Time `json:"time"`
}

func NewMonitoringService() *MonitoringService {
	return &MonitoringService{
		metrics: make(map[string]float64),
		alerts:  make([]MonitoringAlert, 0),
	}
}

func (s *MonitoringService) RecordMetric(name string, value float64) {
	s.metrics[name] = value
}

func (s *MonitoringService) GetMetrics() map[string]float64 {
	return s.metrics
}

func (s *MonitoringService) CreateAlert(message, severity string) {
	alert := MonitoringAlert{
		ID:       fmt.Sprintf("alert_%d", time.Now().UnixNano()),
		Message:  message,
		Severity: severity,
		Time:     time.Now(),
	}
	s.alerts = append(s.alerts, alert)
}

func (s *MonitoringService) GetAlerts() []MonitoringAlert {
	return s.alerts
}
