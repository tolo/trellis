---
title: Input
description: A native single-line form control.
layout: ui_component
component: input
tokens: [--background, --foreground, --input, --ring, --radius]
---

Use an input with a visible label. Pass standard attributes such as `type`,
`name`, and `autocomplete` to the native control.

## Example

<!-- tl:ui_input -->

```html
<label for="reference-email">Work email</label>
<input tl:replace="~{trellis-ui/input :: input}" id="reference-email"
  type="email" name="email" autocomplete="email">
```

## Date fields

For a single date, use a native `<input type="date">`. The browser provides
the date control without JavaScript. Place the labelled field inside your form
and set its `name` so the form submits the date.

```html
<label for="appointment-date">Appointment date</label>
<input type="date" id="appointment-date" name="appointment_date">
```

### Calendar and range recipe

Use Cally 0.9.2 when you need a calendar view. Keep the labelled native inputs
visible and editable. A single field submits one ISO date (`YYYY-MM-DD`). A range
submits two fields, one for each endpoint. In the admin form, the range can be
empty. When supplied, both dates must be valid and in order.

Download [`cally-0.9.2.tgz`](https://registry.npmjs.org/cally/-/cally-0.9.2.tgz)
and verify the archive SHA-256
`b09eb28d713b8798eaca028916755230e517766112d1803086bf958bbb292adb`.
Copy `package/dist/cally.js` unchanged to `/js/cally-0.9.2.js` in the app's static
directory. Its SHA-256 is
`4dcba6a3b8ec63b66ff2fbfc6cf47b7dee1eb4896eac89fe7487d82e28e15870`.
Keep `package/LICENSE` beside it as `cally-0.9.2.LICENSE`. Copy the
[admin recipe module](https://github.com/tolo/trellis/blob/main/examples/admin_app/static/js/contact-dates.js)
as `/js/contact-dates.js`. Load it once after the same-origin HTMX and Trellis UI
scripts. Serving both modules from the app lets `script-src 'self'; style-src 'self'`
cover the form, its styles and the calendar.

```html
<script type="module" src="/js/contact-dates.js"></script>
```

Inside a form, pair one native date with the suite Popover. Seed `value` from the
saved server value when editing. Keep the Popover wrapper hidden in the server
markup so a failed module request leaves the native date field ready to use.

```html
<div data-date-picker data-locale="sv-SE" data-first-day-of-week="1"
  data-previous-label="Föregående" data-next-label="Nästa">
  <label for="visit-date">Visit date</label>
  <input id="visit-date" type="date" name="appointment_date">
  <div data-calendar hidden>
    <div tl:replace="~{trellis-ui/popover :: popover('visit-calendar')}">
      <tl:block tl:slot="trigger">Choose visit date</tl:block>
    </div>
  </div>
</div>
```

Use `data-range` and put the start and end fields in submission order inside the
same root. The recipe seeds Cally's range property with `YYYY-MM-DD/YYYY-MM-DD`
and writes both inputs when the reader completes the selection.

```html
<fieldset data-date-picker data-range data-locale="sv-SE" data-first-day-of-week="1"
  data-previous-label="Föregående" data-next-label="Nästa">
  <legend>Availability dates</legend>
  <label for="visit-start">Start date</label>
  <input id="visit-start" type="date" name="range_start">
  <label for="visit-end">End date</label>
  <input id="visit-end" type="date" name="range_end">
  <div data-calendar hidden>
    <div tl:replace="~{trellis-ui/popover :: popover('availability-calendar')}">
      <tl:block tl:slot="trigger">Choose availability dates</tl:block>
    </div>
  </div>
</fieldset>
```

Use the same lifecycle for each HTMX integration.

1. On initial load and `htmx:afterSwap`, mount each new recipe root once. Keep a
   pristine copy of its server-rendered markup. Create the calendar, read the
   inputs into its `value` property and reveal the Popover trigger.
2. On `htmx:beforeCleanupElement`, remove listeners for any widget the swap
   removes. Cally's disconnected lifecycle releases the removed calendar.
3. On `htmx:beforeHistorySave`, synchronously remove enhancements and restore
   the pristine markup. This keeps mounted calendars, open popovers, transient
   styles and unsaved picks out of the snapshot.
4. After the save turn, mount still-connected roots again. On
   `htmx:historyRestore`, mount the restored roots from their saved inputs. A
   cache miss returns fresh server markup through the same path.

Cally has no audited accessibility programme. The upstream statement records
April 2024 as the last screen-reader test round. Test the composed form with the
assistive technology your readers use. [Cally accessibility statement](https://wicky.nillia.ms/cally/accessibility/)

## Keyboard interaction

Tab focuses the input. In text fields, arrow keys move the caret and typing
edits the value. Enter can submit the containing form.

## Accessibility notes

Match the label’s `for` to the input’s ID. Link help and validation messages
with `aria-describedby` and set `aria-invalid` for an invalid value.
