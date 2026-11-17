---
title: Table
description: Render column headings and caller-owned rows in a scroll region.
layout: ui_component
component: table
tokens: [--foreground, --muted, --muted-foreground, --border, --ring]
columns: [Account, Invoice, Billing email, Status]
invoices:
  - {account: Northfield Studio, invoice: INV-10231, email: billing@nfs.example, status: Paid}
  - {account: Riverside Garden, invoice: INV-10232, email: billing@rg.example, status: Pending}
---

Pass a heading list and row maps. The direct `tbody` slot keeps the caller’s
row markup valid before Trellis parses it. Scroll horizontally on a narrow
screen to see the remaining columns.

## Example

<!-- tl:ui_table -->

```html
<table tl:replace="~{trellis-ui/table :: table('Recent invoices', columns, invoices)}">
  <tbody tl:slot="row">
    <tr class="trellis-table-row">
      <td class="trellis-table-cell" tl:text="${row.account}">Account</td>
      <td class="trellis-table-cell" tl:text="${row.invoice}">Invoice</td>
      <td class="trellis-table-cell" tl:text="${row.email}">Email</td>
      <td class="trellis-table-cell" tl:text="${row.status}">Status</td>
    </tr>
  </tbody>
</table>
```

Supply the example data as YAML front matter on a site using the source,
or as a context map in an application.

```yaml
columns: [Account, Invoice, Billing email, Status]
invoices:
  - {account: Northfield Studio, invoice: INV-10231, email: billing@nfs.example, status: Paid}
  - {account: Riverside Garden, invoice: INV-10232, email: billing@rg.example, status: Pending}
```

## Keyboard interaction

Tab focuses the scroll region. Arrow keys scroll horizontally when the
table is wider than its wrapper. Interactive cells keep their own keyboard
behavior.

## Accessibility notes

Use a useful caption so the table and its scroll region have a name.
Keep header cells associated with their columns. Keep scrolling on the
table wrapper to preserve page reflow.
