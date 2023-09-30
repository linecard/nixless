[private]
default:
  just --list

# # load image(s) into docker
# load image tag:
#   docker load < image.tar.gz
#   docker tag {{image}}:{{tag}} {{image}}:latest

# publish image tag:
#   #!/usr/bin/env bash
  

# # build OCI-compliant image
# # build image tag: (manifest image tag)

oci: list
  #!/usr/bin/env bash
  cd image
  list_digest=$(sha256sum < manifest-list.json | sed 's/  -//')
  list_size=$(stat -f %z manifest-list.json)
  cat <<-EOF > index.json
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

  cat <<-EOF > oci-layout
    {
      "imageLayoutVersion": "1.0.0"
    }
  EOF


[private]
list: manifests
  #!/usr/bin/env bash
  cd image
  amd64_digest=$(sha256sum < manifest-amd64.json | sed 's/  -//')
  amd64_size=$(stat -f %z manifest-amd64.json)
  arm64_digest=$(sha256sum < manifest-arm64.json | sed 's/  -//')
  arm64_size=$(stat -f %z manifest-arm64.json)
  cat <<-EOF > manifest-list.json
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
    cat <<-EOF > config-$arch.json
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
    config_size=$(stat -f %z config-$arch.json)
    layer_digest=$(sha256sum < $arch.tar.gz | sed 's/  -//')
    layer_size=$(stat -f %z $arch.tar.gz)
    cat <<-EOF > manifest-$arch.json
    [
      {
        "schemaVersion": 2,
        "mediaType": "application/vnd.oci.image.config.v1+json",
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
    ]
  EOF
  done  

# [private]
# configs image:
#   #!/usr/bin/env bash
#   cd image
#   diff_digest=$(gunzip < layer.tar.gz | sha256sum | sed 's/  -//')
#   cat <<-EOF > config.json
#   {
#     "architecture": "{{arch}}",
#     "os": "linux",
#     "config": {
#       "Env": ["PATH=/bin"],
#       "Entrypoint": ["app"]
#     },
#     "rootfs": {
#       "type": "layers",
#       "diff_ids": ["sha256:${diff_digest}"]
#     }
#   }
#   EOF

[private]
layers: build
  #!/usr/bin/env bash
  platforms=(amd64 arm64)
  for arch in ${platforms[@]}; do
      cd image/$arch
      tar -czvf ../$arch.tar.gz *
      cd ../..
      rm -rf image/$arch
  done

[private]
build:
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
