## 0.2.0

- `trellis build` command — runs the full trellis_site SSG pipeline from `trellis_site.yaml`, including SASS/SCSS compilation via trellis_css.
  - `--output` (`-o`), `--drafts`, and `--verbose` (`-v`) options.
- `trellis serve` command — local static file server with clean URL support for previewing built sites.
  - `--port` (`-p`) and `--output` (`-o`) options.
- `trellis create --template blog` — blog starter template generating a complete trellis_site project (Markdown content, Trellis layouts, taxonomies, styles).

## 0.1.0

- Initial release.
- `trellis create <project-name>` command for project scaffolding.
- Generates Shelf + HTMX + Trellis projects with all middleware and hot reload.
- Templates demonstrate `tl:extends`, `tl:define`, `tl:insert`, `tl:each`, `tl:text`.
- `--version` and `--help` flags.
- Project name validation (Dart naming rules + reserved word check).
