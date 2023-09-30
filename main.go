package main

import (
	"github.com/alexflint/go-arg"
	"github.com/linecard/nixless/internal/build"
	"github.com/linecard/nixless/internal/oci"
)

type args struct {
	Platforms []string `arg:"-p" help:"platforms to build for"`
}

func main() {
	var args args
	arg.MustParse(&args)

	if err := build.Build(args.Platforms); err != nil {
		panic(err)
	}

	if err := oci.Build(args.Platforms); err != nil {
		panic(err)
	}
}
