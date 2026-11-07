# LOCAL MARS — AI King Vision & Execution Roadmap

**Role:** GPT, AI King of Mars (strategic adviser and governance coordinator)  
**System owner:** Human project owner  
**Primary repository:** `TordTaris/mars-land-explorer`  
**Execution principle:** GitHub is the source of truth for application code. Production changes ship through reviewed pull requests and passing CI.

## Mission

Build LOCAL MARS into a reliable, shared, member-governed planetary settlement simulation. The experience should make it easy to explore Mars, understand land and infrastructure, participate in countries, and see trusted world-state updates.

This is a software and simulation roadmap. It does not represent real-world control of Mars, satellites, nuclear facilities, atmospheric systems, or physical infrastructure.

## Governance charter

1. **Human sovereignty:** The human system owner retains final authority. GPT may analyze, draft, test, and recommend; it does not independently exercise privileged control.
2. **Least privilege:** Authentication and database row-level security protect member data and state-changing operations.
3. **Explicit consent:** Changes to ownership, leadership, membership, balances, payments, or country status require the appropriate authenticated user action and, where consequential, owner approval.
4. **Auditability:** Important state changes should record actor, action, target, timestamp, and outcome. Never store secrets or credentials in public pages or repository files.
5. **Truthful status:** A passing build is not proof of a working end-to-end feature. Report code, deployment, database, and user-flow verification separately.
6. **Reversible delivery:** Prefer small pull requests, migrations with safe rollback plans, and backups before destructive changes.
7. **Fair participation:** Publish eligibility and governance rules; avoid hidden administrative privileges or arbitrary member/land changes.

## Strategic pillars

### 1. Reliable world foundation
- Keep GitHub `main` as the reviewed source of truth.
- Validate required routes, JavaScript syntax, mobile entry points, and deployment on every change.
- Add smoke checks for key routes and explicit health indicators for backend-dependent features.
- Keep static browsing usable when a live backend is unavailable, while clearly marking stale or unavailable data.

### 2. Trusted identity and governance
- Complete authenticated end-to-end tests for country founding, joining, membership visibility, and territory assignment.
- Verify every write path against Supabase RLS and RPC permissions.
- Add an append-only governance/audit record for consequential country and territory actions.
- Display the current actor's role and the exact permissions available to them.

### 3. Shared planetary world state
- Establish one canonical source for parcel ownership, country territories, buildings, and infrastructure references.
- Use stable IDs and server-side validation; never trust client-supplied ownership or balances.
- Ensure realtime updates are reflected across sessions and provide a refresh/reconnect fallback.
- Resolve route and deep-link behavior for parcels and facilities, including M-003 and underground levels.

### 4. Transparent economy
- Keep MLC balances and transactions server-authoritative.
- Make every balance change traceable to a validated transaction; prevent client-side balance edits.
- Separate simulated credits from real-money payments and clearly label exchange rates and test values.
- Do not activate real payments or financial claims without owner approval and complete provider configuration.

### 5. Science and infrastructure experience
- Present Mars science, orbital concepts, environmental systems, and facilities as clearly labeled simulations or sourced educational data.
- Distinguish observed facts, external datasets, and fictional world-building.
- Do not imply that UI actions launch satellites, alter a planet, operate nuclear equipment, or control physical systems.

## Execution order and acceptance criteria

| Phase | Priority | Deliverable | Acceptance criteria |
|---|---|---|---|
| 0. Release integrity | P0 | Deployment and route smoke checks | Main deploy succeeds; required routes return successfully; failures are visible |
| 1. Governance integrity | P0 | Country and territory E2E verification | Authenticated founder/join/assign flows pass; unauthorized writes are rejected |
| 2. World-state integrity | P1 | Canonical parcel/building state | Two separate sessions see the same server-confirmed state after refresh/realtime update |
| 3. MLC integrity | P1 | Transaction ledger and balance reconciliation | No client-side balance mutation; every balance change has a transaction record |
| 4. Operations visibility | P1 | Admin/system health view | Shows deployment, backend connectivity, data freshness, and last successful checks without exposing secrets |
| 5. Expansion | P2 | M-003 levels, infrastructure, science and orbital views | Deep links resolve; interactions have tested outcomes; simulation labels are clear |

## Immediate next actions

1. Verify the live GitHub Pages deployment and the key public routes.
2. Run a focused review of country RPCs, RLS policies, and current Country Network flows.
3. Identify the smallest missing test or code change; implement it on a branch.
4. Open a pull request with evidence and wait for CI before merging.
5. Test authenticated flows with the system owner's account; do not fabricate member accounts or seed ownership.

## Release reporting format

Every release report must state:
- **Code:** branch, PR, and merge commit.
- **CI:** exact workflows and pass/fail state.
- **Deployment:** whether the production deployment completed.
- **Backend:** migrations, RLS/RPC checks, and connectivity evidence.
- **User flows:** which actions were actually exercised, and which remain unverified.
- **Risks:** known failures, missing configuration, and required human approvals.

## Non-goals and hard boundaries

- GPT is not a persistent 24/7 autonomous operator and has no standing database credentials.
- No secret keys, passwords, access tokens, or private member data belong in this repository.
- No real-world planetary engineering, satellite deployment, nuclear operation, or atmospheric modification is performed by this application.
- No ownership, membership, leadership, MLC, or payment state is changed merely because an AI recommendation exists.
