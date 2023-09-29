arch := 'arm64'

[private]
default:
  just --list

# load image(s) into docker
load image tag:
  docker load < image.tar.gz
  docker tag {{image}}:{{tag}} {{image}}:latest

# build OCI-compliant image
build image tag arch=arch: (manifest image tag arch)
  #!/usr/bin/env bash
  cd image
  rm -rf layer
  tar -czvf ../image.tar.gz *
  cd ../

[private]
manifest image tag arch: (config image arch)
  #!/usr/bin/env bash
  cd image
  layer_digest=$(sha256sum < layer.tar.gz | sed 's/  -//')
  config_digest=$(sha256sum < config.json | sed 's/  -//')
  cat <<-EOF > manifest.json
  [
    {
      "config": "config.json",
      "repoTags": ["{{image}}:{{tag}}"],
      "layers": [
        "layer.tar.gz"
      ]
    }
  ]
  EOF

[private]
config image arch: (layer arch)
  #!/usr/bin/env bash
  cd image
  diff_digest=$(gunzip < layer.tar.gz | sha256sum | sed 's/  -//')
  cat <<-EOF > config.json
  {
    "architecture": "{{arch}}",
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

[private]
layer arch: (binary arch)
  #!/usr/bin/env bash
  cd image/layer
  tar -czvf ../layer.tar.gz *

[private]
binary arch: tree 
  #!/usr/bin/env bash
  CGO_ENABLED=0 GOOS=linux GOARCH={{arch}} \
    go build -o image/layer/bin/app

[private]
tree: 
  #!/usr/bin/env bash
  rm -rf image
  mkdir -p image/layer && cd image/layer
  mkdir bin # dev etc proc sys

[private]
clean:
  rm -rf image
  rm -rf *.tar.gz
