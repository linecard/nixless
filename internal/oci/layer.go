package oci

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

func layer(platform string) error {
	wd, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("error getting working directory: %w", err)
	}

	tarDir := filepath.Join(wd, "oci", platform)
	outPath := filepath.Join(wd, "oci", platform+".tar.gz")

	// Create a tar.gz file
	tarGzFile, err := os.Create(outPath)
	if err != nil {
		return fmt.Errorf("error creating tar.gz file: %w", err)
	}
	defer tarGzFile.Close()

	// Create a gzip writer
	gzipWriter := gzip.NewWriter(tarGzFile)
	defer gzipWriter.Close()

	// Create a tar writer
	tarWriter := tar.NewWriter(gzipWriter)
	defer tarWriter.Close()

	// Walk through the directory and add files to the tarball
	err = filepath.Walk(tarDir, func(path string, info fs.FileInfo, err error) error {
		if err != nil {
			return fmt.Errorf("error walking directory: %w", err)
		}

		// Get file info
		fileInfo, err := os.Stat(path)
		if err != nil {
			return fmt.Errorf("error getting file info: %w", err)
		}

		// Skip the base directory itself
		if path == tarDir {
			return nil
		}

		// Create a tar header
		header, err := tar.FileInfoHeader(fileInfo, fileInfo.Name())
		if err != nil {
			return fmt.Errorf("error creating tar header: %w", err)
		}

		// Modify the header's name to remove the base path
		header.Name = strings.TrimPrefix(strings.Replace(path, tarDir, "", -1), string(filepath.Separator))

		// Set a default name if header.Name is empty
		if header.Name == "" {
			header.Name = fileInfo.Name()
		}

		// Write the header to the tarball
		if err := tarWriter.WriteHeader(header); err != nil {
			return fmt.Errorf("error writing tar header: %w", err)
		}

		// If the file is not a directory, write the file to the tarball
		if !fileInfo.IsDir() {
			file, err := os.Open(path)
			if err != nil {
				return fmt.Errorf("error opening file: %w", err)
			}
			defer file.Close()

			_, err = io.Copy(tarWriter, file)
			if err != nil {
				return fmt.Errorf("error copying file to tarball: %w", err)
			}
		}

		return nil
	})
	if err != nil {
		return fmt.Errorf("error creating tarball: %w", err)
	}

	// Delete the archived directory
	if err := os.RemoveAll(tarDir); err != nil {
		return fmt.Errorf("error deleting directory: %w", err)
	}

	return nil
}
