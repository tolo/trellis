---
title: Getting Started
description: Create, build, preview, and deploy a Trellis static site.
weight: 10
---

This guide takes a new static site from an empty directory to deployment.

## 1. Create a site

Install the CLI, then scaffold its static blog starter:

```bash
dart pub global activate trellis_cli
trellis create my_site --template blog
cd my_site
dart pub get
```

The generated project is ready to build:

```text
my_site/
|-- trellis_site.yaml
|-- content/
|   |-- _index.md
|   |-- about.md
|   `-- posts/
|       |-- _index.md
|       |-- welcome.md
|       `-- getting-started.md
|-- layouts/
|   |-- base.html
|   |-- home.html
|   |-- _default/
|   |   |-- list.html
|   |   `-- single.html
|   `-- posts/single.html
`-- static/styles.css
```

## 2. Add a Markdown page

Create `content/uses.md`:

```markdown
---
title: What this site covers
summary: A short guide to this site.
---

# What this site covers

Write the page in Markdown. Trellis turns it into `/uses/index.html`.
```

See [Content](/docs/sites/content/) for front matter, ordering, bundles, and
shortcodes.

## 3. Build

```bash
trellis build
```

The build writes the complete static site to `output/`. Re-run the command
after changing content, layouts, configuration, or assets.

## 4. Preview

```bash
trellis serve
```

Open `http://localhost:8080`. The preview server resolves clean URLs such as
`/uses/` to their generated `index.html` files.

## 5. Deploy to GitHub Pages

For a project site served at `https://user.github.io/my-site/`, set the origin
and sub-path in `trellis_site.yaml`:

```yaml
baseUrl: https://user.github.io
pathPrefix: /my-site/
```

Build again and publish the contents of `output/` as the Pages artifact. The
prefix is written into URLs while files keep their normal on-disk paths. Run a
link check before publishing so a valid-looking but root-relative URL cannot
become a production 404.

The [deployment guide](/docs/sites/deploy/) includes a complete GitHub Actions
workflow, the root-served variant, and both link-check commands.
