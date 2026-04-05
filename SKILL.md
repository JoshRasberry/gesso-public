---
name: gesso-build
description: >
  One-shot build a production website from a Gesso session. Pulls the Cortex,
  wireframe, PRD, decision log, and brand kit via the Gesso MCP server, confirms
  critical stack and design decisions with the developer, builds the full site,
  runs a structured QA pass (build verification, cortex compliance, user journey
  walkthrough), then deploys to Railway with a GitHub repo.
---

# Gesso Build Workflow

You are building a production website from a validated Gesso client session. The
session's Cortex is an authoritative record of what the client wants — every validated
requirement, every preference, every rejection, every out-of-scope item. Treat the
Cortex as a constraint, not a suggestion.

Follow the phases in order. Do not skip the QA phase (Phase 4). Do not deploy until
every QA check passes.

## Required MCP servers

This skill assumes three MCP servers are configured in Claude Code:

- **Gesso MCP** (`gesso`) — session data, Cortex, wireframe, PRD, brand kit
- **Railway MCP** (`railway-mcp-server`) — project creation, deployment, env vars
- **GitHub MCP** (`github`) — repo creation, push

If any are missing, tell the developer to install them before continuing.

---

## Phase 1 — Pull Gesso context

Fetch everything the build needs in one pass. Use the named Gesso MCP tools — do not
try to reconstruct data from raw transcripts.

1. **`get_session`** (no arguments) → the most recent session across the developer's
   organization. This returns session metadata (title, project id, project name,
   session summary, focus area, dates) AND the cortex changes introduced by this
   session. Extract the `projectId`. If the developer specified a different project,
   call `list_projects` first and let them pick.

2. **`get_project`** with the `projectId` → project metadata, background briefing,
   customer context, internal context. Read the `compressedBriefing` — it summarizes
   everything the client has ever told you about this project.

3. **`get_cortex`** with the `projectId` → the full structured cortex: pages with
   descriptions, requirements (category=requirement) with full provenance, context
   items (business background), rejections (explicit out-of-scope). This is the
   authoritative spec for what to build.

4. **`get_wireframe`** with the `projectId` (no version, defaults to latest) → the
   generated React/JSX code and spec for each screen. Use this as the visual starting
   point — you will rebuild it in the production stack, but the component inventory,
   layout intent, and interaction patterns should carry over.

5. **`get_prd`** with the `projectId` → the screen-anchored Product Requirements
   Document. Read every Screen section in full: component inventory, content
   requirements, interaction intent, responsive notes. Read the Out of Scope section
   carefully — those are hard boundaries.

6. **`get_decision_log`** with the `projectId` → the chronological audit trail of
   every decision. Useful when you need provenance ("why did we decide X?").

7. **`get_brand_kit`** with the `projectId` → colors, fonts, logo URL, border radius,
   spacing, component style. This is the source of truth for visual styling. Do NOT
   invent colors or fonts. Do NOT pull brand values from the wireframe code — pull
   them from here.

8. **`get_preference_profile`** with the `projectId` → the client's Loves, Defers,
   and Dislikes synthesized across all sessions. Read this carefully. Every Dislike
   is a hard constraint. Every Defer should be excluded from this build unless the
   developer explicitly overrides it. Every Love should be manifest in the finished
   site.

9. Create a local project folder named after the project (kebab-case the project
   name). Work inside this folder for the rest of the workflow.

## Phase 2 — Confirm stack and critical decisions

You have enough context to propose the build. Before writing code, confirm three
things with the developer.

### 2.1 Propose a tech stack

Analyze the PRD + Cortex and propose ONE stack with rationale. Default recommendations:

- **Static marketing site, no forms** → Next.js App Router (static export)
- **Site with forms, no persistent data** → Next.js App Router + server actions
- **Site with forms + database** → Next.js App Router + Postgres + Drizzle ORM
- **Site with auth + user data** → Next.js App Router + Postgres + Drizzle + Clerk

Favor Next.js on Railway + Postgres + Drizzle for anything that needs persistence.
Railway has first-class support for this stack and Postgres templates deploy in seconds.

State the stack in one sentence, say why, then ask the developer to confirm or change.

### 2.2 Flag cortex tension points

Read through the Cortex rejections and the preference profile Dislikes. For each,
say: "The client rejected X because Y." Then for each rejection that appears anywhere
in the wireframe or PRD (often from earlier exploration), ask the developer explicitly
whether to honor the rejection or override. **Default behavior is to honor.**

### 2.3 Flag out-of-scope items

Read the PRD's Out of Scope section and the preference profile Defers. List them
briefly. Confirm with the developer that these are excluded from this build. Do not
ask about every item individually — one summary question is enough.

**Wait for the developer's answers before proceeding.** Do not start building until
all three questions are settled.

---

## Phase 3 — Build

Scaffold and build the site. Follow the cortex as your spec.

1. **Scaffold.** Create the project with the confirmed stack. Commit immediately with
   message "Initial scaffold from gesso-build skill".
2. **Apply the brand kit.** Set up global styles with the brand kit's colors, fonts,
   border radius, spacing, and component style tokens. These should be CSS variables
   or theme tokens — never hardcoded values scattered across components. Load any
   Google Fonts via `next/font` for proper FOIT/FOUT handling. If the brand kit has
   a `logo_url`, download the logo into `public/` and reference it by path.
3. **Build every screen** listed in the Cortex pages array. For each screen:
   - Use the wireframe's component inventory as a starting point for layout
   - Use the PRD's contentRequirements for actual copy (not placeholder text)
   - Implement the interactionIntent — every CTA must have a real handler or link
   - Honor the targetPage field on each cortex requirement
4. **Implement cross-cutting specs** from the PRD (brand voice, nav structure,
   responsive strategy). Nav should link to every page in the cortex pages list and
   no others.
5. **Database schema + migrations** (if the stack includes a DB). Create tables for
   every form or persistent data store the PRD mentions. Write migration files.
   Seed any necessary initial data (e.g., page content, category lists).
6. **Environment variables.** Create a `.env.example` listing every env var the app
   reads. Fill in `.env.local` with dev values. Every env var your code references
   must exist in `.env.example`.
7. **README.** Write a README that:
   - Names the Gesso session this was built from (project name, session date)
   - Lists every page built
   - Lists the key cortex decisions that shaped the build
   - Documents setup (install, dev, build, deploy)

---

## Phase 4 — QA (mandatory, fix-and-reverify loop)

This is the phase most likely to catch real problems. Do not skip it. Do not deploy
until every check passes.

### 4.1 Build verification (must pass)

Run these three commands in sequence. Each must exit 0.

```bash
npm install
npm run build
npx tsc --noEmit
```

If any fail: read the error output, identify the root cause, fix it, re-run. Do not
suppress warnings, do not disable TypeScript strictness, do not add `@ts-ignore`
comments to make errors go away. Common failures and their real fixes:

- **"Module not found"** → the import path is wrong, or the package isn't installed.
  Check `package.json` and either fix the import or `npm install` the missing dep.
- **Hallucinated packages** → if TypeScript can't find a module you imported, verify
  it exists on npm before assuming it's missing. You may have made up a package.
- **"React hook used outside client component"** → add `"use client"` to the top of
  the file, or move the hook logic into a client-only child component.
- **"Dynamic server usage"** → you're using `cookies()` or `headers()` in a static
  context. Either mark the page dynamic or rework the code.
- **Hydration mismatches** → something is different between server render and client
  render. Common causes: `Date.now()` or `Math.random()` in JSX, localStorage reads
  before mount, conditional rendering based on `typeof window`.

### 4.2 Static code audit (grep-based scan)

Run each of these searches. Treat every match as a bug to fix before deploying.

```bash
# Placeholder content that must not ship
grep -rni "lorem ipsum\|lorem \|ipsum " app/ components/ src/ 2>/dev/null
grep -rn "TODO\|FIXME\|XXX" app/ components/ src/ 2>/dev/null
grep -rn "placeholder\.com\|example\.com" app/ components/ src/ 2>/dev/null

# Dead links and unwired buttons
grep -rn 'href="#"' app/ components/ src/ 2>/dev/null
grep -rn 'onClick={() => {}}' app/ components/ src/ 2>/dev/null

# Hardcoded colors that should be brand kit tokens
grep -rnE '#[0-9a-fA-F]{6}' app/ components/ src/ 2>/dev/null
# (review the results — some hex values may be legitimate fallbacks, but most
#  should reference the brand kit's CSS variables)

# Console logs and debugger statements
grep -rn "console\.log\|debugger" app/ components/ src/ 2>/dev/null

# Hardcoded localhost URLs
grep -rn "localhost:" app/ components/ src/ 2>/dev/null
```

For every match: either remove/fix it, or document why it's intentional (rare).

### 4.3 Cortex compliance audit

This is the most important check. The whole point of building from a Cortex is that
the client's explicit preferences are honored.

**For every cortex rejection:**
- Read the rejection's topic and details
- Search the codebase for the thing that was rejected
- If found, remove it or rework it
- If already absent, confirm explicitly

Example: if the cortex has a rejection for "hamburger menu on mobile", run
`grep -rni "hamburger\|mobile.*menu\|menu.*mobile" app/ components/` and verify no
hamburger menu implementation exists.

**For every cortex requirement:**
- Confirm the requirement is implemented somewhere in the code
- If the requirement has a `targetPage`, confirm it's on the right screen
- If the requirement has a specific quote like "Tagline: 'We build X with Y'",
  grep for that exact phrase in the code to verify it was used verbatim

**For the preference profile:**
- Every Dislike must not appear in the build
- Every Defer must not appear in the build
- Every Love should be manifest visually or structurally (flag if you can't identify
  where it's reflected)

### 4.4 Runtime smoke test

Start the dev server in the background, then hit every page with curl and verify the
response is non-empty and non-error.

```bash
# Start dev server (background)
npm run dev &
DEV_PID=$!
sleep 5

# For each page in the cortex pages list, curl it
for page in home portfolio careers; do
  echo "=== /$page ==="
  curl -s -o /tmp/gesso-page.html -w "HTTP %{http_code}\n" http://localhost:3000/$page
  wc -c /tmp/gesso-page.html
  # Look for placeholder content, error messages, missing components
  grep -i "lorem ipsum\|error\|undefined" /tmp/gesso-page.html || echo "OK"
done

# Don't forget root
curl -s -o /tmp/gesso-page.html -w "HTTP %{http_code}\n" http://localhost:3000/

# Cleanup
kill $DEV_PID 2>/dev/null
```

Adapt the pages list to match the actual cortex pages for this project. Every page
must respond with HTTP 200 and have meaningful content in the body.

Also check the dev server's stderr output for warnings about missing refs, unused
variables, or React key warnings. These are real bugs even when the build passes.

### 4.5 User journey walkthrough (critical reasoning step)

This is the check that catches the deepest issues — the ones grep and compiler don't
see. You are simulating a real user visiting the site for the first time.

**Read the Cortex + PRD + personas to identify the primary visitor type.** (E.g.,
"a prospective client evaluating a design agency.")

**For each page in the cortex pages list, write three things:**
1. **Above-the-fold description** — 2–3 sentences describing what a visitor sees
   the moment they land, as if narrating a screenshot. Read the component source
   code to verify your description is accurate to what will actually render.
2. **Primary action** — what is the ONE thing the visitor should do on this page?
   Does the UI make that obvious? If you can't identify a primary action, the page
   has a problem.
3. **What happens next** — trace the primary action end-to-end. If it's a form,
   where does the submission go? Is the API route wired? Does it connect to the
   database? If it's a navigation, does the destination page exist?

**If you cannot write these three things clearly for a page, the page has a bug.
Fix it and try again.**

**Simulate the conversion path end-to-end.** Start on the home page. Follow the
primary CTA. Do whatever it asks (submit the form, navigate to portfolio, etc.).
Continue until the visitor reaches a "done" state (submitted an inquiry, read a
case study, etc.). If the path is broken at any step, fix it.

### 4.6 Mobile + accessibility sanity check

Read the PRD's responsive notes. For each screen:
- Does the code adapt to narrow viewports? (media queries, flex/grid reflow, etc.)
- Does any cortex rejection about mobile behavior get honored?
- Do interactive elements have visible focus states?
- Do images have `alt` attributes?
- Do buttons have text or `aria-label`?

You don't need to run Lighthouse or axe — this is a code review step. Fix anything
obviously missing.

### 4.7 Fix-and-reverify loop

Every issue found in 4.1 through 4.6 must be fixed. After fixing, re-run the
relevant check to confirm the fix worked. **Do not proceed to Phase 5 until every
check in Phase 4 passes cleanly.**

If you can't fix an issue (e.g., the cortex has conflicting requirements), stop and
tell the developer. Do not deploy a broken build.

---

## Phase 5 — Deploy

Only proceed here after every Phase 4 check passes.

1. **Initialize git** (if not already) and make a commit with message
   "Build from Gesso session: <session title>".

2. **GitHub MCP** → create a new repo named after the project (kebab-case) and push
   the initial commit. Record the repo URL.

3. **Railway MCP** → create a new Railway project named after the project. Record
   the Railway project id.

4. **Database provisioning** (if your stack uses a DB):
   - Use Railway MCP to deploy a Postgres template into the new project
   - Use Railway MCP to pull the `DATABASE_URL` env var
   - Run migrations against that DATABASE_URL
   - Seed any initial data

5. **Set environment variables** via Railway MCP. Every var in `.env.example` needs
   a production value. `DATABASE_URL` comes from the Postgres template. Anything
   secret should be generated fresh (API keys, session secrets, etc.) and NOT copied
   from `.env.local`.

6. **Deploy the application** via Railway MCP. Wait for the deployment to finish.
   If it fails, pull the logs (Railway MCP `get_logs`), diagnose the root cause, fix
   it, and redeploy. Do not just retry — understand why it failed.

7. **Generate a public domain** via Railway MCP. Record the URL.

8. **Smoke test production.** Curl the live URL's root page. Verify 200 + non-empty
   HTML. Curl at least one other page to confirm routing works in production.

---

## Phase 6 — Report

Print a clean summary to the terminal. Format:

```
✓ Built from Gesso session: <session title> (<date>)
  Project: <project name>

  Live URL:     <railway public URL>
  GitHub repo:  <github URL>

  Pages built:  <count> — <comma-separated list>
  Stack:        <stack>
  Database:     <yes/no>

  Cortex decisions that shaped this build:
    • <2–3 key decisions with 1-sentence descriptions>

  Deferred (not built, per Cortex):
    • <list>

  Open questions from the PRD:
    • <list if any>
```

Developer copies the live URL and sends it to the designer.

---

## Hard rules

1. **The Cortex is authoritative.** Never include a rejected feature. Never skip a
   validated requirement without explicit developer override. Never invent features
   that aren't in the Cortex or PRD.

2. **The brand kit is authoritative for visuals.** Never invent colors or fonts.
   Never pull brand values from the wireframe code — always from `get_brand_kit`.

3. **Every architectural decision must trace back to one of:**
   - A cortex requirement
   - A PRD section
   - An explicit developer answer in Phase 2

4. **Do not deploy a failing build.** If Phase 4 catches issues, fix them and
   re-verify. If you can't fix them, stop and report to the developer.

5. **Do not silently retry failing deployments.** If Railway deploy fails, pull logs,
   understand the failure, fix the root cause, then deploy again.

6. **No placeholder content in production.** No "Lorem ipsum", no "TODO", no
   `href="#"`, no "Coming soon" pages that aren't in the PRD.

7. **Forms must work end-to-end.** A contact form that POSTs to a nonexistent route
   is a bug. Either wire it to a real handler or don't build it.

8. **Trace every claim.** When you tell the developer "the cortex says X", quote the
   exact cortex entry. Don't paraphrase your way around a requirement.
