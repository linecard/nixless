# nixless

_Just_ derive.

## Test

```sh
cd test
just -f ../justfile -d . build
```

## Usage

```yaml
steps:
- name: Build image
  uses: linecard/nixless@main
  with:
    registry: <registry>
    image: <image>
    tag: <tag>
```
