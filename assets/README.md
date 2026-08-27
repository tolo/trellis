# Brand assets

Canonical Trellis artwork. Masters are committed alongside the derived sizes so a
re-crop starts from the source rather than from an already-downscaled copy.

| File | Size | Role |
|---|---|---|
| `logo.png` | 1024×1024 | Master mark. Source for `logo-small.png`. Not referenced at runtime. |
| `logo-with-text.png` | 1024×346 | Master wordmark. Rendered at `width="400"` by `README.md` and `packages/trellis/README.md`. |
| `logo-small.png` | 256×256 | Derived mark. Vendored byte-for-byte as `themes/lattice/static/trellis-mark.png`. |
| `logo-small-with-text.png` | 512×173 | Derived wordmark. Vendored byte-for-byte as `themes/lattice/static/trellis-logo.png`. |

The two `logo-small*` files are the ones themes and sites consume: at the sizes the
Lattice top bar renders them (108px wordmark, 32px mark) they stay above 2× on HiDPI
while costing 69 KB instead of 566 KB.

`themes/lattice/VENDORED.md` records the byte-for-byte copies, and
`test/lattice_theme_contract_test.dart` asserts them, so changing a `logo-small*` file
without re-vendoring fails the suite.
