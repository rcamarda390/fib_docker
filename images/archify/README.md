# Archify image

This image packages the stable Archify agent skill and CLI from
`tt-a1i/archify`. The upstream tag and commit are both pinned in `image.yaml`.
It includes Chromium for `visual-check` and disables Archify's optional update
check, so rendering and validation need no runtime internet access.

Generate the bundled demonstration:

```bash
docker run --rm -v "$PWD:/workspace" rcamarda390/archify:2.16.0-v1 \
  demo /workspace/archify-demo
```

Render a diagram from a JSON definition in the current directory:

```bash
docker run --rm -v "$PWD:/workspace" rcamarda390/archify:2.16.0-v1 \
  render architecture /workspace/system.architecture.json /workspace/system.html
```

The complete skill is available inside the image at `/opt/archify`, including
`SKILL.md`, schemas, examples, renderers, validators, and reference material.
