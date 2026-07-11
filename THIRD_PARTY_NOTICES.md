# Third-Party Notices

Wicked.jl source code in this repository is licensed under the MIT License in `LICENSE.md`.

## Runtime dependencies

The package currently declares only Julia standard-library dependencies:

- `Base64`
- `Dates`
- `REPL`
- `UUIDs`
- `Unicode`

These libraries are distributed as part of Julia and remain subject to the licenses and third-party notices shipped with the corresponding Julia distribution. They are not vendored into this repository.

## Development infrastructure

GitHub Actions workflows reference maintained actions from GitHub and the Julia Actions organization. Those actions execute in CI and are not included in Wicked.jl package artifacts.

## Vendored material

As of 2026-07-11, this repository contains no vendored third-party source code, fonts, images, terminal protocol implementations, or generated external datasets requiring a separate bundled notice.

Terminal protocol compatibility names such as Kitty, Sixel, iTerm2, Ratatui, Textual, TamboUI, and Lanterna identify external projects or protocols. Their mention does not imply incorporation of their source code or endorsement by their owners.

When adding vendored code, generated data, media, or other redistributable third-party material, update this file in the same change and include the required license text and provenance.
