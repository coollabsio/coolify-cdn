package main

import (
	"bytes"
	"crypto/md5"
	"embed"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

//go:embed json/*
var jsonFiles embed.FS

// loadJSONFiles recursively loads all JSON files from the embedded filesystem
func loadJSONFiles(dir, prefix string, files map[string]*fileData, etags map[string]string) error {
	entries, err := jsonFiles.ReadDir(dir)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		fullPath := dir + "/" + entry.Name()

		if entry.IsDir() {
			// Recursively process subdirectories
			newPrefix := prefix + "/" + entry.Name()
			if err := loadJSONFiles(fullPath, newPrefix, files, etags); err != nil {
				return err
			}
		} else if strings.HasSuffix(entry.Name(), ".json") {
			// Load JSON file
			content, err := jsonFiles.ReadFile(fullPath)
			if err != nil {
				log.Printf("Failed to read embedded file %s: %v", fullPath, err)
				continue
			}

			// Create URL path (remove "json" prefix and add leading slash)
			urlPath := prefix + "/" + entry.Name()

			files[urlPath] = &fileData{
				content: content,
				modTime: time.Now(), // Use build time as mod time
			}

			// Calculate ETag
			hash := md5.Sum(content)
			etags[urlPath] = fmt.Sprintf("\"%x\"", hash)
		}
	}

	return nil
}

func main() {
	// Read base FQDN from environment variable, default to coolify.io
	baseFQDN := os.Getenv("BASE_FQDN")
	if baseFQDN == "" {
		baseFQDN = "coolify.io"
	}

	// Create a map of embedded files with metadata
	files := make(map[string]*fileData)
	etags := make(map[string]string)

	// Recursively load all JSON files from embedded json directory
	err := loadJSONFiles("json", "", files, etags)
	if err != nil {
		log.Fatal("Failed to load JSON files:", err)
	}

	log.Printf("Loaded %d JSON files: %v", len(files), getFileList(files))
	log.Printf("Base FQDN for redirects: %s", baseFQDN)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		handleRequest(w, r, baseFQDN, files, etags)
	})

	log.Println("Starting server on :80")
	log.Fatal(http.ListenAndServe(":80", nil))
}

func handleRequest(w http.ResponseWriter, r *http.Request, baseFQDN string, files map[string]*fileData, etags map[string]string) {
	// Set CORS headers
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept")

	// Handle OPTIONS requests for CORS preflight
	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	// Handle root path redirect
	if r.URL.Path == "/" {
		http.Redirect(w, r, "https://"+baseFQDN, http.StatusFound)
		return
	}

	// Handle health check
	if r.URL.Path == "/health" {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("healthy\n"))
		return
	}

	// Check if file exists
	fileData, exists := files[r.URL.Path]
	if !exists {
		// 404 redirect to base FQDN with request_uri
		http.Redirect(w, r, "https://"+baseFQDN+r.RequestURI, http.StatusFound)
		return
	}

	// Set content type for JSON files
	if strings.HasSuffix(r.URL.Path, ".json") {
		w.Header().Set("Content-Type", "application/json")
	}

	// Set cache control
	w.Header().Set("Cache-Control", "public, must-revalidate")

	// Handle ETag caching manually for embedded files
	etag := etags[r.URL.Path]
	w.Header().Set("ETag", etag)

	// Check If-None-Match header
	if match := r.Header.Get("If-None-Match"); match == etag {
		w.WriteHeader(http.StatusNotModified)
		// Include ETag in 304 response as per HTTP spec
		w.Header().Set("ETag", etag)
		return
	}

	// Use http.ServeContent for range request support and Last-Modified handling
	reader := bytes.NewReader(fileData.content)
	http.ServeContent(w, r, filepath.Base(r.URL.Path), fileData.modTime, reader)
}

type fileData struct {
	content []byte
	modTime time.Time
}

func getFileList(files map[string]*fileData) []string {
	var names []string
	for path := range files {
		names = append(names, path)
	}
	return names
}
