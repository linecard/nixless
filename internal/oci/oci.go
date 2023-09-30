package oci

import (
	"fmt"
)

func Build(platforms []string) error {
	for _, platform := range platforms {
		if err := layer(platform); err != nil {
			return fmt.Errorf("error creating layer: %w", err)
		}
	}

	return nil
}
