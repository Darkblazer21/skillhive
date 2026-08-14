# SkillHive

Two-sided freelancer/SME marketplace, portfolio showcase project (design
tier **Flagship**, business/marketplace theme). Target: agencies and
SMEs considering digitizing a matchmaking activity. The platform serves
two distinct audiences at once, freelancers looking for missions and
SMEs looking for reliable providers, and needs to build trust on both
sides simultaneously.

## Scope

- Rich provider and client profiles
- Search and filtering
- Real-time messaging between the two parties
- Ratings and reviews after each completed mission
- Escrow payment, released on explicit two-sided confirmation

## Stack

- Backend: FastAPI + WebSockets for real-time messaging, PostgreSQL via
  SQLAlchemy with complex relations, multi-role RBAC
- Frontend: Next.js / React / TypeScript + shadcn/ui
- Infra: Docker Compose for local development; demo deploy on Railway
  for the backend (WebSockets need a persistent process, not a
  serverless function) and Vercel for the frontend

## Agent team active on this project

Global config (`~/.config/opencode/`), no local `.opencode/` copy.

- Tech Lead, orchestrator, always active
- Design Director / Design Critic, art direction, Flagship tier
  calibration (`/new-design-brief`, then `/design-review` after
  implementation)
- Backend Architect, data model, real-time messaging, escrow logic
- Frontend Architect, marketplace UI, consumes the design contract
  once frozen by Design Director
- DevOps/Cloud, Docker Compose setup, Railway and Vercel deploy
- QA/Tests, test generation on the messaging and escrow flows
- Security/Review, review before every delivery, particularly on the
  RBAC and payment logic

Out of scope for this project: IA/RAG Specialist. SkillHive has no
AI/RAG component.

## Project-specific conventions

- Design tier: Flagship (~$55,000 indicative). Full bespoke design
  system expected. No adaptation of a generic marketplace template.
  See `design-tier-flagship` for the calibration this implies on every
  dimension.
- Escrow release is always gated on explicit confirmation from both
  sides. Never automatic on a timer, even for a demo flow.
- Messaging is built real-time-first with WebSockets. Not polling
  dressed up to look real-time.
- Open question to test on this project specifically: how Design
  Director handles profile imagery (real photos, sourced stock, or
  generated) given the trust role images play in a two-sided
  marketplace. Document the actual approach taken in this section once
  decided, since this is currently an open point in the broader
  workflow rather than a settled convention.

## Out of scope

- Real escrow fund movement. Simulated or sandbox payment only.
- Multi-currency support.
- A full dispute-resolution or arbitration workflow. A basic
  flag-for-review state is enough for this showcase.
