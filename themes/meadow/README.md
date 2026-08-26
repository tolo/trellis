# Meadow

Meadow is a self-contained Trellis landing theme with the Fresh Bloom visual language: Bricolage Grotesque display
type, Schibsted Grotesk body text, JetBrains Mono code, a lime headline marker, color-blocked feature cards, and a
theme-owned trellis illustration. It works offline and supports `light`, `dark`, and OS-aware `auto` skins.

## Preview

From `themes/meadow/example`, run `trellis build`, then serve `output/`. To preview a fixture without changing tracked
content, copy the example to a temporary directory, replace only `content/_index.md` with the chosen
`fixtures/<name>/_index.md`, retain the `themes/meadow` link, and run `trellis build` there. Use
`trellis_site.subpath.yaml` as the temporary config to verify a `/trellis/` deployment. Fixtures cover short and long
copy, 2–6 features, split layout without media, each optional section absent, and all optional sections absent.

## Params

Meadow implements all 18 [standard params](../../docs/reference/standard-params.md) plus the landing params below:

| Param | Type | Default | Purpose |
|---|---|---|---|
| `skin` | `light \| dark \| auto` | `auto` | Color scheme; auto follows OS until explicitly toggled |
| `primary_color` | color | `#237a48` | Leaf green links and accents |
| `accent_color` | color | `#d4f15f` | Lime marker and primary highlight |
| `text_color` | color | `#14251a` | Main light-skin ink |
| `muted_color` | color | `#476050` | Secondary light-skin ink |
| `bg_color` | color | `#f7faee` | Light-skin page background |
| `surface_color` | color | `#fffef8` | Light-skin raised surface |
| `border_color` | color | `#d4e2ce` | Light-skin rules and dividers |
| `font_family` | string | `Schibsted Grotesk, …` | Body font stack |
| `heading_font_family` | string | `Bricolage Grotesque, …` | Display font stack |
| `code_font_family` | string | `JetBrains Mono, …` | Code font stack |
| `max_width` | string | `1180px` | Maximum content width |
| `border_radius` | string | `24px` | Shared card radius |
| `nav_links` | list | four home-section links | Header and footer navigation `{label,url}` items |
| `social_links` | list | `[]` | Optional footer `{platform,label,url}` items |
| `footer_text` | string/null | `null` | Optional footer copy |
| `show_powered_by` | boolean | `true` | Show the Trellis attribution |
| `show_rss_link` | boolean | `true` | Emit feed discovery links when feeds exist |
| `excerpt_length` | int | `160` | Plain-text list summary length |
| `hero_align` | `center \| split` | `split` | Hero composition; absent media always centers |
| `pill_badges` | boolean | `true` | Rounded eyebrow labels |
| `logo` | string/null | `null` | Optional theme-local logo path |
| `sky_color` | color | `#69b9ea` | Sky card accent |
| `sun_color` | color | `#ffd367` | Sun card accent |
| `bloom_color` | color | `#cf91ef` | Bloom card accent |
| `coral_color` | color | `#fb907b` | Coral illustration accent |

## Home content

| Block | Fields |
|---|---|
| `hero` | escaped `eyebrow`, `headline.{prefix,emphasis,suffix}`, `lede`, `ctas[].{label,href,style}`, optional `media.{src,alt}` |
| `proof` | `items[].{value,label}` |
| `features` | `eyebrow`, `title`, `body`, `items[].{icon,title,body}` |
| `workflow` | `eyebrow`, `title`, `body`, `signals[].{initials,name,source,text,tag}`, `insight.{label,title,body,confidence}` |
| `use_cases` | `eyebrow`, `title`, `body`, `items[].{label,title,body,href}` |
| `quote` | `text`, `attribution` |
| `cta` | `eyebrow`, `title`, `body`, `command`, `note`, optional `terminal_label` |

Only `headline.emphasis` receives Meadow's theme-owned marker. Supplying `hero.media` enables the illustration slot;
without it, a split hero centers and reserves no media gap. Add `media.src` — a prefix-relative image path — to mount
your own artwork there; with only `media.alt` the theme-owned trellis drawing is used. Markdown below front matter
renders once. `cta.terminal_label` names the terminal chrome and falls back to the site title, so no demo brand
is baked into the layout.
Each optional block may be omitted independently and removes its wrapper and spacing.

Feature lists support exactly the authored 2–6 cards, cycling four treatments in a three-column desktop and
single-column mobile grid. Copy is always escaped and containers have no fixed text height, so short copy stays compact
and long copy wraps and grows. `layouts/_default/single.html` and `list.html` cover ordinary pages and sections.

## Accessibility and scripts

The shell begins with a skip link and preserves header, navigation, main, and footer landmarks. Controls meet the 44px
mobile target, focus is visible, and reduced-motion removes smooth scroll, card lift, and other transitions. Auto skin
uses a small first-party script to persist an explicit choice over OS preference; forced skins emit neither the toggle
nor the pre-paint override. With JavaScript disabled, auto follows the OS and copy controls remain hidden rather than
dead. See [VENDORED.md](VENDORED.md) for asset provenance.
