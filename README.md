# SkillHive

A two-sided marketplace connecting freelancers with SMEs looking for
reliable providers. Built as a portfolio showcase project at design
tier Flagship, using an agent-driven development workflow.

## What this is

SkillHive lets an SME post a need and browse provider profiles, and
lets a freelancer build a profile and get discovered. Once matched, the
two sides communicate through real-time messaging, agree on a mission,
and the payment sits in escrow until both sides confirm completion.
Reviews accumulate on each provider's profile afterward.

This is a demo project, not a live product with real users. Payment is
simulated. See `AGENTS.md` for the full scope and what is intentionally
left out.

## Stack

- **Backend**: FastAPI, PostgreSQL (SQLAlchemy), WebSockets for
  real-time messaging
- **Frontend**: Next.js, React, TypeScript, shadcn/ui
- **Infra**: Docker Compose for local development, Railway for the
  backend, Vercel for the frontend

## Getting started

```bash
git clone <this-repo>
cd skillhive
cp .env.example .env
docker compose up
```

The backend serves the API on `http://localhost:8000`, the frontend on
`http://localhost:3000`. Check `.env.example` for the environment
variables each service expects.

### Git hooks

After cloning, run:

```bash
bash hooks/install.sh
```

This installs the pre-commit checks (secret detection, prose pattern
lint on `design/`) and the commit message format check. See
`hooks/README.md` for what each one does.

## Project structure

```
backend/     FastAPI app: api, schemas, services, repositories, models
frontend/    Next.js app: app, components, hooks, lib
design/      Design contract frozen by Design Director: tokens,
             wireframes, and the portfolio content under design/portfolio/
docs/        Architecture and setup notes
hooks/       Git hooks, installed once per clone with hooks/install.sh
```

## Working with the agent team

This project is built through an agent-driven workflow rather than by
hand. `AGENTS.md` at the repo root lists which agents are active for
this engagement and what each one owns. A few entry points worth
knowing:

- `/new-design-brief` starts a design phase for a new screen. It always
  runs before any frontend implementation work.
- `/design-review` audits an implemented screen against the design
  brief. It always runs before `/code-review`.
- `/security-review` covers the OWASP checklist on the messaging and
  escrow logic in particular.

## Status

Work in progress. Not deployed as a real product, no real user data.
