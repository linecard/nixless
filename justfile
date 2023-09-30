[private]
default:
  just --list

# build and publish the multi-architecture image
publish registry image tag: build
  #!/usr/bin/env bash
  skopeo \
    --insecure-policy \
    copy --all \
    --format oci \
    oci://$(pwd)/image docker://{{registry}}/{{image}}:{{tag}}

# build the multi-architecture image
build: clean shape

[private]
shape: index
  #!/usr/bin/env bash
  cd image
  mkdir -p blobs/sha256
  mv *.tar.gz blobs/sha256/
  mv *.json blobs/sha256/
  mv blobs/sha256/index.json .
  for file in $(find blobs/sha256 -type f); do
    digest=$(sha256sum < $file | sed 's/  -//')
    mv $file blobs/sha256/$digest
  done

[private]
index: list
  #!/usr/bin/env bash
  cd image
  list_digest=$(sha256sum < manifest-list.json | sed 's/  -//')
  list_size=$(stat -c %s manifest-list.json)
  cat <<-EOF | jq -c | tr -d '\n' > index.json
    {
      "schemaVersion": 2,
      "manifests": [
        {
          "mediaType": "application/vnd.oci.image.index.v1+json",
          "digest": "sha256:${list_digest}",
          "size": ${list_size}
        }
      ]
    }
  EOF

  cat <<-EOF | jq -c | tr -d '\n' > oci-layout
    {
      "imageLayoutVersion": "1.0.0"
    }
  EOF


[private]
list: manifests
  #!/usr/bin/env bash
  cd image
  amd64_digest=$(sha256sum < manifest-amd64.json | sed 's/  -//')
  amd64_size=$(stat -c %s manifest-amd64.json)
  arm64_digest=$(sha256sum < manifest-arm64.json | sed 's/  -//')
  arm64_size=$(stat -c %s manifest-arm64.json)
  cat <<-EOF | jq -c | tr -d '\n' > manifest-list.json
  {
    "schemaVersion": 2,
    "mediaType": "application/vnd.oci.image.index.v1+json",
    "manifests": [
      {
        "mediaType": "application/vnd.oci.image.manifest.v1+json",
        "digest": "sha256:${amd64_digest}",
        "size": ${amd64_size},
        "platform": {
          "architecture": "amd64",
          "os": "linux"
        }
      },
      {
        "mediaType": "application/vnd.oci.image.manifest.v1+json",
        "digest": "sha256:${arm64_digest}",
        "size": ${arm64_size},
        "platform": {
          "architecture": "arm64",
          "os": "linux"
        }
      }
    ]
  }
  EOF

[private]
manifests: layers
  #!/usr/bin/env bash
  cd image
  platforms=(amd64 arm64)
  for arch in ${platforms[@]}; do
    diff_digest=$(gunzip < $arch.tar.gz | sha256sum | sed 's/  -//')
    cat <<-EOF | jq -c | tr -d '\n' > config-$arch.json
    {
      "architecture": "${arch}",
      "os": "linux",
      "config": {
        "Env": ["PATH=/bin"],
        "Entrypoint": ["app"]
      },
      "rootfs": {
        "type": "layers",
        "diff_ids": ["sha256:${diff_digest}"]
      }
    }
  EOF

    config_digest=$(sha256sum < config-$arch.json | sed 's/  -//')
    config_size=$(stat -c %s config-$arch.json)
    layer_digest=$(sha256sum < $arch.tar.gz | sed 's/  -//')
    layer_size=$(stat -c %s $arch.tar.gz)
    cat <<-EOF | jq -c | tr -d '\n' > manifest-$arch.json
    {
      "schemaVersion": 2,
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "config": {
        "mediaType": "application/vnd.oci.image.config.v1+json",
        "digest": "sha256:${config_digest}",
        "size": ${config_size}
      },
      "layers": [
        {
          "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
          "digest": "sha256:${layer_digest}",
          "size": ${layer_size}
        }
      ]
    }
  EOF
  done

[private]
layers: binaries
  #!/usr/bin/env bash
  platforms=(amd64 arm64)
  for arch in ${platforms[@]}; do
      cd image/$arch
      tar -czvf ../$arch.tar.gz *
      cd ../..
      rm -rf image/$arch
  done

[private]
binaries:
  #!/usr/bin/env bash
  platforms=(amd64 arm64)
  for arch in ${platforms[@]}; do
    mkdir -p image/$arch/bin
    CGO_ENABLED=0 GOOS=linux GOARCH=$arch \
      go build -o image/$arch/bin/app
  done

[private]
clean:
  rm -rf image
  rm -rf *.tar.gz
