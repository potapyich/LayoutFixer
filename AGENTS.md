# AGENTS.md

## Scope
These instructions apply to the entire repository unless a deeper `AGENTS.md` overrides them.

## Working Style
- Keep changes focused on the user's request.
- Prefer root-cause fixes over cosmetic patches.
- Preserve existing project structure and naming unless a change is required.
- Avoid broad refactors unless the user explicitly asks for them.

## File Safety
- Do not overwrite unrelated user changes.
- Do not delete files or run destructive git commands unless explicitly requested.
- Prefer small, reviewable diffs.

## Editing Guidelines
- Match the surrounding code style and conventions.
- Use ASCII by default unless a file already requires Unicode.
- Add comments only when they clarify non-obvious logic.
- Update nearby documentation when behavior or workflows change.

## Validation
- Run the smallest relevant validation first.
- If tests or builds are expensive, validate only the area changed unless the user asks for more.
- If validation cannot be run, state that clearly in the final handoff.

## Repo Hygiene
- Do not commit, create branches, or rewrite history unless explicitly requested.
- Keep generated files and local artifacts out of version control.
- If `.gitignore` is missing, create a minimal one before finishing changes.

## Communication
- Summarize what changed, why it changed, and any validation performed.
- Call out assumptions, blockers, and follow-up work explicitly.
