package build

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func Build(platforms []string) error {
	for _, platform := range platforms {
		wd, err := os.Getwd()
		if err != nil {
			return fmt.Errorf("error getting working directory: %w", err)
		}

		outPath := filepath.Join(wd, "oci", platform, "bin")
		if err := os.MkdirAll(outPath, os.ModePerm); err != nil {
			return fmt.Errorf("error creating output directory: %w", err)
		}

		buildCmd := exec.Command("go", "build", "-o", outPath)
		buildCmd.Env = append(
			os.Environ(),
			"CGO_ENABLED=0",
			"GOOS=linux",
			"GOARCH="+platform,
		)

		buildCmd.Stdout = os.Stdout
		buildCmd.Stderr = os.Stderr

		err = buildCmd.Run()
		if err != nil {
			return fmt.Errorf("error building binary: %w", err)
		}
	}

	return nil
}
