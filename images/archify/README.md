# Archify image

This image packages the stable Archify agent skill and CLI from
`tt-a1i/archify`. The upstream tag and commit are both pinned in
`image.yaml`. It intentionally omits the optional Chromium/FFmpeg runtime
dependency and disables Archify's optional update check, so the core CLI needs
no runtime internet access.

Archify's browser-backed `visual-check` command can use a compatible browser
provided by the surrounding runtime through `ARCHIFY_CHROME`; without a
browser, that optional check is skipped. Core commands such as `demo`,
`render`, and `validate` remain available in this image.

Generate the bundled demonstration:

```bash
docker run --rm -v "$PWD:/workspace" rcamarda390/archify:2.16.0-v3 \
  demo /workspace/archify-demo
```

Render a diagram from a JSON definition in the current directory:

```bash
docker run --rm -v "$PWD:/workspace" rcamarda390/archify:2.16.0-v3 \
  render architecture /workspace/system.architecture.json /workspace/system.html
```

The complete skill is available inside the image at `/opt/archify`, including
`SKILL.md`, schemas, examples, renderers, validators, and reference material.
