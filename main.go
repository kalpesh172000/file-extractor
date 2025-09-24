package main

import (
	"bufio"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	version = "1.0.0"
)

type Config struct {
	inputDir        string
	outputFile      string
	includeExts     []string
	excludeExts     []string
	includeDirs     []string
	excludeDirs     []string
	maxFileSize     int64
	followSymlinks  bool
	verbose         bool
	showVersion     bool
	showHelp        bool
}

func main() {
	config := parseFlags()
	
	if config.showVersion {
		fmt.Printf("File Content Extractor v%s\n", version)
		return
	}
	
	if config.showHelp {
		flag.Usage()
		return
	}
	
	if config.inputDir == "" {
		config.inputDir = "."
	}
	
	if config.outputFile == "" {
		config.outputFile = fmt.Sprintf("extracted_content_%s.txt", 
			time.Now().Format("20060102_150405"))
	}
	
	if config.verbose {
		fmt.Printf("Starting extraction from: %s\n", config.inputDir)
		fmt.Printf("Output file: %s\n", config.outputFile)
	}
	
	err := extractFiles(config)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
	
	if config.verbose {
		fmt.Println("Extraction completed successfully!")
	}
}

func parseFlags() Config {
	var config Config
	
	flag.StringVar(&config.inputDir, "dir", ".", "Input directory to scan")
	flag.StringVar(&config.inputDir, "d", ".", "Input directory to scan (short)")
	flag.StringVar(&config.outputFile, "output", "", "Output file name (default: extracted_content_TIMESTAMP.txt)")
	flag.StringVar(&config.outputFile, "o", "", "Output file name (short)")
	
	var includeExts, excludeExts, includeDirs, excludeDirs string
	flag.StringVar(&includeExts, "include-ext", "", "Comma-separated list of file extensions to include (e.g., '.go,.txt,.md')")
	flag.StringVar(&includeExts, "ie", "", "Include extensions (short)")
	flag.StringVar(&excludeExts, "exclude-ext", "", "Comma-separated list of file extensions to exclude (e.g., '.exe,.bin,.jpg')")
	flag.StringVar(&excludeExts, "ee", "", "Exclude extensions (short)")
	
	flag.StringVar(&includeDirs, "include-dir", "", "Comma-separated list of directory names to include")
	flag.StringVar(&includeDirs, "id", "", "Include directories (short)")
	flag.StringVar(&excludeDirs, "exclude-dir", "", "Comma-separated list of directory names to exclude (e.g., 'node_modules,.git,vendor')")
	flag.StringVar(&excludeDirs, "ed", "", "Exclude directories (short)")
	
	flag.Int64Var(&config.maxFileSize, "max-size", 10*1024*1024, "Maximum file size in bytes (default: 10MB)")
	flag.Int64Var(&config.maxFileSize, "ms", 10*1024*1024, "Maximum file size (short)")
	
	flag.BoolVar(&config.followSymlinks, "follow-symlinks", false, "Follow symbolic links")
	flag.BoolVar(&config.followSymlinks, "fs", false, "Follow symlinks (short)")
	flag.BoolVar(&config.verbose, "verbose", false, "Verbose output")
	flag.BoolVar(&config.verbose, "v", false, "Verbose (short)")
	flag.BoolVar(&config.showVersion, "version", false, "Show version")
	flag.BoolVar(&config.showHelp, "help", false, "Show help")
	flag.BoolVar(&config.showHelp, "h", false, "Show help (short)")
	
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "File Content Extractor v%s\n\n", version)
		fmt.Fprintf(os.Stderr, "Usage: %s [OPTIONS]\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "OPTIONS:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nEXAMPLES:\n")
		fmt.Fprintf(os.Stderr, "  %s -d ./src -o output.txt -ie '.go,.md' -ed 'vendor,.git'\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s --include-ext '.py,.js' --exclude-dir 'node_modules,__pycache__'\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s --max-size 5242880 --verbose\n", os.Args[0])
	}
	
	flag.Parse()
	
	// Parse comma-separated values
	if includeExts != "" {
		config.includeExts = parseCommaSeparated(includeExts)
	}
	if excludeExts != "" {
		config.excludeExts = parseCommaSeparated(excludeExts)
	}
	if includeDirs != "" {
		config.includeDirs = parseCommaSeparated(includeDirs)
	}
	if excludeDirs != "" {
		config.excludeDirs = parseCommaSeparated(excludeDirs)
	}
	
	return config
}

func parseCommaSeparated(input string) []string {
	parts := strings.Split(input, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

func extractFiles(config Config) error {
	outputFile, err := os.Create(config.outputFile)
	if err != nil {
		return fmt.Errorf("failed to create output file: %v", err)
	}
	defer outputFile.Close()
	
	writer := bufio.NewWriter(outputFile)
	defer writer.Flush()
	
	// Write header
	fmt.Fprintf(writer, "File Content Extraction Report\n")
	fmt.Fprintf(writer, "Generated: %s\n", time.Now().Format("2006-01-02 15:04:05"))
	fmt.Fprintf(writer, "Source Directory: %s\n", config.inputDir)
	fmt.Fprintf(writer, "%s\n\n", strings.Repeat("=", 50))
	
	fileCount := 0
	
	walkFunc := func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			if config.verbose {
				fmt.Printf("Warning: Error accessing %s: %v\n", path, err)
			}
			return nil
		}
		
		// Handle symbolic links
		if d.Type() == fs.ModeSymlink && !config.followSymlinks {
			return nil
		}
		
		// Skip directories
		if d.IsDir() {
			dirName := d.Name()
			
			// Check if directory should be excluded
			if shouldExcludeDir(dirName, config.excludeDirs) {
				if config.verbose {
					fmt.Printf("Skipping excluded directory: %s\n", path)
				}
				return filepath.SkipDir
			}
			
			// Check if we have include filters and this dir doesn't match
			if len(config.includeDirs) > 0 && !shouldIncludeDir(dirName, config.includeDirs) {
				// Only skip if it's not a parent directory that might contain included dirs
				return nil
			}
			
			return nil
		}
		
		// Check file extension filters
		ext := strings.ToLower(filepath.Ext(path))
		
		if len(config.includeExts) > 0 && !contains(config.includeExts, ext) {
			return nil
		}
		
		if len(config.excludeExts) > 0 && contains(config.excludeExts, ext) {
			return nil
		}
		
		// Check file size
		info, err := d.Info()
		if err != nil {
			if config.verbose {
				fmt.Printf("Warning: Cannot get file info for %s: %v\n", path, err)
			}
			return nil
		}
		
		if info.Size() > config.maxFileSize {
			if config.verbose {
				fmt.Printf("Skipping large file: %s (%d bytes)\n", path, info.Size())
			}
			return nil
		}
		
		// Check if file is binary
		if isBinaryFile(path) {
			if config.verbose {
				fmt.Printf("Skipping binary file: %s\n", path)
			}
			return nil
		}
		
		// Read and write file content
		content, err := os.ReadFile(path)
		if err != nil {
			if config.verbose {
				fmt.Printf("Warning: Cannot read file %s: %v\n", path, err)
			}
			return nil
		}
		
		// Write file path and content to output
		fmt.Fprintf(writer, "%s\n\n", path)
		writer.Write(content)
		fmt.Fprintf(writer, "\n\n%s\n\n", strings.Repeat("-", 50))
		
		fileCount++
		if config.verbose {
			fmt.Printf("Processed: %s\n", path)
		}
		
		return nil
	}
	
	err = filepath.WalkDir(config.inputDir, walkFunc)
	if err != nil {
		return fmt.Errorf("error walking directory: %v", err)
	}
	
	// Write footer
	fmt.Fprintf(writer, "\nExtraction Summary\n")
	fmt.Fprintf(writer, "Files processed: %d\n", fileCount)
	fmt.Fprintf(writer, "Completed: %s\n", time.Now().Format("2006-01-02 15:04:05"))
	
	return nil
}

func shouldExcludeDir(dirName string, excludeDirs []string) bool {
	for _, excludeDir := range excludeDirs {
		if strings.EqualFold(dirName, excludeDir) {
			return true
		}
	}
	return false
}

func shouldIncludeDir(dirName string, includeDirs []string) bool {
	for _, includeDir := range includeDirs {
		if strings.EqualFold(dirName, includeDir) {
			return true
		}
	}
	return false
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if strings.EqualFold(s, item) {
			return true
		}
	}
	return false
}

func isBinaryFile(filename string) bool {
	file, err := os.Open(filename)
	if err != nil {
		return false
	}
	defer file.Close()
	
	// Read first 512 bytes to check for binary content
	buffer := make([]byte, 512)
	n, err := file.Read(buffer)
	if err != nil {
		return false
	}
	
	// Check for null bytes which indicate binary content
	for i := 0; i < n; i++ {
		if buffer[i] == 0 {
			return true
		}
	}
	
	return false
}
