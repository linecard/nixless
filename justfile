[private]
default:
  just --list

load:
  cat image.tar.gz | docker load

image: manifest
  #!/usr/bin/env bash
  cd image
  rm -rf layer
  tar -czvf ../image.tar.gz *

[private]
manifest: config
  #!/usr/bin/env bash
  cd image
  layer_digest=$(sha256sum < layer.tar.gz | sed 's/  -//')
  # layer_size=$(stat -f %z layer.tar.gz)
  config_digest=$(sha256sum < config.json | sed 's/  -//')
  # config_size=$(stat -f %z config.json)
  cat <<-EOF > manifest.json
  [
    {
      "config": "config.json",
      "repoTags": ["hello:latest"],
      "layers": [
        "layer.tar.gz"
      ]
    }
  ]
  EOF

[private]
config: layer
  #!/usr/bin/env bash
  cd image
  diff_digest=$(gunzip < layer.tar.gz | sha256sum | sed 's/  -//')
  cat <<-EOF > config.json
  {
    "architecture": "arm64",
    "os": "linux",
    "config": {
      "Env": ["PATH=/bin"],
      "Entrypoint": ["hello"]
    },
    "rootfs": {
      "type": "layers",
      "diff_ids": ["sha256:${diff_digest}"]
    }
  }
  EOF

[private]
layer: build
  #!/usr/bin/env bash
  cd image/layer
  tar -czvf ../layer.tar.gz *

[private]
build: tree 
  #!/usr/bin/env bash
  cd src
  GOOS=linux \
    GOARCH=arm64 \
    go build -o ../image/layer/bin/hello

[private]
tree: 
  #!/usr/bin/env bash
  rm -rf image
  mkdir -p image/layer && cd image/layer
  mkdir bin dev etc proc sys

[private]
clean:
  rm -rf image
  rm -rf image.tar.gz
