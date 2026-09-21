# AI Decision Record: Exempt URLs in Commit Body from Line Length Limit

## Context & Goal
Commit messages frequently include reference URLs or metadata trailers (such as `AI-Reasoning: <url>`) that naturally exceed 72 characters. The `.githooks/commit-msg` hook previously failed validations on any body line exceeding 72 characters, rejecting legitimate commit messages containing links.

## Architecture & Key Decisions
- **URL Line Exemption**: Align with `project-template` by skipping line-length enforcement on lines containing `http://` or `https://` (`*http://* | *https://*`).
- **Preserve Standard Validation**: Maintain strict 72-character limit on the title and all other non-URL body lines.

## Alternatives Considered & Rejected
- *Trailer-only Exemption*: Only exempting specific trailer keywords (`AI-Reasoning:`, `Co-authored-by:`) would reject markdown links or plain reference URLs in the commit body.
- *Increasing Max Body Width*: Relaxing the line length globally degrades formatting and readability in standard terminal pagers and Git interfaces.
