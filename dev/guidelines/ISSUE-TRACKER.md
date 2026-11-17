# Issue Tracker

Backend: Linear
<!-- Maintainer-only. Linear is the planning tracker (trial from 2026-11-13, evaluated when 0.14 ships). A contributor
     without access to the Linear workspace files and follows issues on GitHub (see GitHub intake below) and cannot
     run `andthen:tracker` against this document. -->

Record: tracker
<!-- Since 2026-11-17 every release's PRD (0.1 onwards) is the description of one issue in its release milestone,
     carrying its andthen-projection line. Plans and FIS for the release in flight live in `dev/spec/<milestone>/`
     on its feature branch until `andthen:ship` removes them. -->

Workspace `Leafnode`, team `Leafnode` (issue keys `LEA-<n>`), shared by every product. Every Trellis issue belongs to
the Linear project `Trellis`, and every list call filters on it. Each release is a milestone in that project named by
its version (`0.13`, `0.14`); an issue without a milestone is unscheduled backlog.

Tech debt is not tracked here. It stays in `dev/state/TECH-DEBT-BACKLOG.md`, because AndThen skills append deferred
findings to that file.

## GitHub intake

GitHub Issues on `tolo/trellis` stay open for bug reports and requests from users. Linear's GitHub Issues Sync
(unidirectional, GitHub → Linear) creates a Linear issue in team `Leafnode` for each new GitHub issue, so triage and
planning happen only in Linear. Linear-only issues (backlog, PRDs, stories) are never pushed to GitHub.

<!-- Not yet enabled (2026-11-17): Settings → Integrations → GitHub → Issues sync. Until it is verified, check whether
     synced issues land in the `Trellis` project or only in the team; if only the team, triage assigns the project and
     `list issues` for triage must also cover team issues without a project. -->

## Operation Table
<!-- Security-critical executable config: review changes as code.
     Each value names one Linear MCP tool (the connector's `mcp__<server>__` prefix varies by host) and its fixed fields.
     Placeholders, each passed as one structured field: <N> the issue key (LEA-123), <title>, <body-file> read as UTF-8
     and passed as the `description` text, <query>, <label>. -->

| Operation      | Backend call |
|----------------|--------------|
| fetch issue    | `get_issue` {id: <N>, fields: [title, description, labels, status, project]}; comments through `list_comments` {issueId: <N>} |
| list issues    | `list_issues` {team: "Leafnode", project: "Trellis", query: <query>, includeArchived: true, fields: [id, title, status, labels, description]} |
| create issue   | `save_issue` {team: "Leafnode", project: "Trellis", title: <title>, description: <body-file>} |
| comment        | `save_comment` {issueId: <N>, body: <body-file>} |
| edit body      | `save_issue` {id: <N>, description: <body-file>} |
| add label      | `save_issue` {id: <N>, addLabels: [<label>]} |
| remove label   | `save_issue` {id: <N>, removeLabels: [<label>]} |
| close issue    | `save_issue` {id: <N>, state: "Canceled"} |

`list issues` search is fuzzy: a `query` for an `andthen-projection` line also returns unrelated issues. Only a hit
whose `description` holds the exact line counts. Linear keeps the HTML comment verbatim but re-serialises the rest of
the Markdown (table rules, bold around code, escapes), so compare a stored body with its source by content, not bytes.

`close issue` is used only by triage (wontfix, already implemented), so it cancels. A shipped story is moved to `Done`
by hand or at release.

## Label Role Mapping

| Canonical role  | Repo label      |
|-----------------|-----------------|
| bug             | Bug             |
| enhancement     | Feature         |
| needs-triage    | needs-triage    |
| needs-info      | needs-info      |
| ready-for-agent | ready-for-agent |
| ready-for-human | ready-for-human |
| wontfix         | wontfix         |

The five state labels are workspace labels in the single-select `Triage` group, so an issue carries at most one.
