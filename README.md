Judgment Engineering

"Research" (https://img.shields.io/badge/Status-Active%20Research-blue)
"Prototype" (https://img.shields.io/badge/Prototype-Working-green)
"License" (https://img.shields.io/badge/License-All%20Rights%20Reserved-lightgrey)
"AI" (https://img.shields.io/badge/AI-Human--Centered-purple)

Preserving Human Judgment as Organizational Memory for AI-Assisted Decision Making

A research initiative exploring how organizations can capture, preserve, reconstruct, evaluate, and improve human judgment using structured methods and responsible AI.

---

Introduction

Organizations preserve decisions through documents, reports, emails, and databases. Yet the reasoning behind those decisions often disappears. As experienced professionals leave, organizations inherit outcomes but lose the judgment that produced them.

Judgment Engineering is an independent research initiative exploring how organizations can systematically capture, preserve, reconstruct, evaluate, and improve human judgment using structured methods and responsible AI.

Rather than preserving only what was decided, Judgment Engineering investigates how organizations can preserve why decisions were made, transforming human reasoning into a reusable organizational asset.

The research has now progressed from conceptual framework and simulations to a working software prototype that demonstrates this principle through structured Judgment Units.

---

Research Question

«How can organizations capture, preserve, and continuously improve the reasoning behind important decisions instead of preserving only their outcomes?»

---

What Is Judgment Engineering?

Judgment Engineering is an emerging discipline for systematically capturing, preserving, retrieving, and improving organizational judgment.

Its core object is the Judgment Unit: a structured record of the reasoning around a decision, including the problem being addressed, options considered, rationale, assumptions, evidence, accepted risks, and success metrics.

The discipline is concerned not only with recording decisions, but with preserving enough of the original judgment that a future person can reconstruct why a decision was made, understand what was known at the time, and later evaluate that judgment against what actually happened.

This repository contains both the research framework behind the discipline and a working prototype used to test the framework in practice.

---

Vision

To establish Judgment Engineering as a scientific and engineering discipline that enables organizations to preserve human judgment as searchable, reusable, and continuously improving organizational memory.

---

Core Principles

Judgment Engineering is built upon four foundational principles:

- Preserve reasoning, not only decisions.
- Treat organizational judgment as a reusable asset.
- Use AI to structure and retrieve human reasoning without replacing human judgment.
- Improve future decisions through preserved organizational learning.

The current prototype focuses on the structured capture, preservation, retrieval, and retrospective evaluation of judgment. AI-assisted capabilities remain part of the broader research direction rather than a claim about functionality already implemented in the prototype.

---

Working Prototype

Live demo: https://judgment-engineering.vercel.app

The prototype demonstrates a four-stage lifecycle:

Capture → Preserve → Retrieve → Retrospective

Capture

A decision's reasoning is recorded while it is still fresh through a structured capture form.

Preserve

The resulting Judgment Unit is stored as a structured, persistent record rather than being left in a meeting conversation, chat thread, or undocumented memory.

Retrieve

Previously captured judgments can be browsed and retrieved so that the reasoning behind a decision can be reconstructed later.

Retrospective

Once an outcome is known, the original judgment can be evaluated against reality: which assumptions held, which failed, what risks materialized, and what should change next time.

The prototype is a working demonstration of the framework, not a claim that organizational decision-making has been solved.

---

The Judgment Unit

Each Judgment Unit captures several connected layers of information.

Metadata & Ownership

- Title
- Department
- Decision owner
- Lifecycle status
- Decision date

Context & Trigger

- What prompted the decision
- Why the decision was required at that point

The Seven Preservation Questions

1. Problem — What problem is being solved?
2. Options considered — What alternatives were available?
3. Rationale — Why was the chosen approach selected?
4. Assumptions — What was believed to be true?
5. Evidence / sources — What information supported the judgment?
6. Risks knowingly accepted — What risks were recognized and accepted?
7. Success metrics — How would success be recognized?

Chosen vs. Rejected Options

The selected option and alternatives that were considered and set aside are preserved separately, including the reasoning for those choices. This supports side-by-side reconstruction of the decision rather than collapsing all alternatives into a single narrative.

Retrospective

Once an outcome is known, a Judgment Unit can be evaluated through:

- Outcome
- Assumptions confirmed
- Assumptions invalidated
- Unexpected risks that materialized
- What would be done differently next time
- Retrospective date

A judgment's lifecycle status and retrospective outcome are deliberately separate.

Status describes where a decision is in its lifecycle: Proposed, Approved, Implemented, or Rejected.

Outcome describes how the decision turned out once it has been evaluated: Success, Partial, or Failure.

Not every Judgment Unit has a retrospective yet. That is expected because retrospective evaluation depends on an outcome becoming available.

---

Five Canonical Judgment Units

The prototype currently contains five canonical Judgment Units demonstrating the framework across different contexts:

ID| Title| Domain
JU-000001| Preserve Judgment, Not Just Decisions| Why Judgment Engineering exists
JU-000002| Deploy Judgment Engineering Prototype to Vercel| Technical implementation judgment
JU-000003| Investigating Intermittent Network Service Degradation| Operational judgment under uncertainty (NOC)
JU-000004| Prioritising Time Sensitive Deliveries Under Limited Rider Capacity| Product / dispatch judgment
JU-000005| Restoring CCTV Coverage When Existing Cabling Failed| Judgment evaluated against reality (Postmortem)

JU-000002 and JU-000005 contain completed retrospective evaluations.

JU-000005 provides the clearest end-to-end demonstration of the lifecycle, carrying a real operational judgment from its original capture through preservation, retrieval, outcome evaluation, and postmortem reflection.

---

Architecture

The prototype is built with:

- Framework: Next.js 16.2.12
- Application model: App Router
- Language: TypeScript
- Build tooling: Turbopack
- Styling: Tailwind CSS
- Database: Supabase / PostgreSQL
- Database client: Supabase JS client
- Deployment: Vercel

The application reads from and writes directly to Supabase through the Supabase JS client. There is no separate API or application server layer.

All Judgment Units are stored in a single "judgment_units" table.

Retrospective information is stored as additional columns on the existing Judgment Unit rather than as a separate retrospective table or separate record. This keeps the original judgment and its later evaluation connected within the same unit.

Environment Variables

The prototype requires two environment variables:

NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY

---

Local Setup

Clone the repository:

git clone https://github.com/edinburghray-cell/Judgment-Engineering.git
cd Judgment-Engineering
npm install

Create a ".env.local" file in the project root:

NEXT_PUBLIC_SUPABASE_URL=your_supabase_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key

Start the development server:

npm run dev

The application will be available at:

http://localhost:3000

The production deployment is hosted on Vercel and is automatically deployed when changes are pushed to "main".

---

Research Framework

The broader Judgment Engineering framework explores five interconnected areas:

- Judgment Capture
- Reasoning Preservation
- Organizational Memory
- AI-Assisted Retrieval
- Continuous Organizational Learning

Detailed framework:

Framework/Research_Framework.md

The working prototype represents an implementation layer built from this broader research framework.

---

Research Simulations

The repository includes visual simulations demonstrating the core concepts of Judgment Engineering through a progressive research narrative.

Simulation 1 — The Loss

How organizations preserve events but lose the reasoning behind critical decisions.

➡️ "Open Simulation 1" (simulations/simulation-1-the-loss/)

Simulation 2 — The Capture

How human judgment can be captured as structured organizational memory.

➡️ "Open Simulation 2" (simulations/simulation-2-the-capture/)

Simulation 3 — The Transfer

How preserved judgment can be transferred to future decision makers and AI-assisted systems.

➡️ "Open Simulation 3" (simulations/simulation-3-the-transfer/)

Simulation 4 — The Institution

How Judgment Engineering becomes an organizational capability through continuous learning.

➡️ "Open Simulation 4" (simulations/simulation-4-the-institution/)

Current Simulations

- Network Operations Center Failure Response
- Engineering Decision Transfer
- Organizational Knowledge Loss
- AI-Assisted Decision Recovery

These simulations form part of the research record and illustrate potential applications of Judgment Engineering across operational and organizational environments.

---

Visual Architecture

The repository includes publication-quality visual figures explaining the conceptual architecture of Judgment Engineering.

Figure 1 — Foundations of Judgment Engineering

"Figure 1" (figures/figure-1-foundations-of-judgment-engineering.png)

Figure 2 — Core Mechanisms of Judgment Engineering

"Figure 2" (figures/figure-2-core-mechanisms-of-judgment-engineering.png)

Figure 3 — Methods and Measurement of Judgment Engineering

"Figure 3" (figures/figure-3-methods-and-measurement-of-judgment-engineering.png)

Figure 4 — Applications of Judgment Engineering

"Figure 4" (figures/figure-4-applications-of-judgment-engineering.png)

Figure 5 — Complete Discipline Architecture

"Figure 5" (figures/figure-5-complete-discipline-architecture.png)

---

Research Contributions

Judgment Engineering introduces and investigates several concepts, including:

- Judgment Units
- Judgment Capture
- Judgment Reconstruction
- Judgment Evaluation
- Judgment Improvement
- Organizational Judgment Lifecycle
- Judgment Preservation
- Judgment Residue
- Organizational Memory for AI

The working prototype provides an implementation environment for testing these concepts rather than treating them as purely theoretical constructs.

---

Why This Research Matters

Organizations already preserve enormous amounts of information.

They rarely preserve the reasoning that produced it.

Judgment Engineering aims to make organizational judgment:

- Explainable
- Searchable
- Traceable
- Transferable
- Continuously improvable

The broader research explores how this could support stronger governance, organizational resilience, responsible AI, and improved institutional learning.

---

Project Status

Judgment Engineering has progressed through several stages:

Completed

- Research Question
- Conceptual Framework
- White Paper / Book Manuscript
- Four Research Simulations
- Visual Architecture
- System Architecture
- Working Judgment Capture Prototype
- Judgment Repository
- Judgment Retrieval
- Retrospective Evaluation
- Production Deployment

Current

- Working public prototype
- Continued research and framework development
- Validation of the Judgment Engineering model through concrete Judgment Units

Planned

- Academic Paper Submission
- Organizational Pilot Studies
- Further development of the Judgment Engineering platform
- Further investigation of AI-assisted judgment retrieval and organizational learning

The prototype is deliberately presented as a working research implementation rather than a finished product.

---

Project History

See ""HISTORY.md"" (./HISTORY.md) for the build journey and the reasoning behind key architectural decisions.

---

Contributing and Research Discussion

Judgment Engineering is an independent research initiative.

Researchers, engineers, knowledge management practitioners, AI researchers, organizational leaders, and students interested in the subject are welcome to engage with the research through constructive feedback, discussion, and collaboration.

The repository is currently published with All Rights Reserved. Code reuse, redistribution, or modification is not granted by this repository unless separately authorized.

---

About

Judgment Engineering is an independent research initiative created by Chijioke Edinburgh Jemanze.

The work combines engineering practice, organizational learning, knowledge management, decision science, and artificial intelligence to investigate new methods for preserving human judgment as organizational memory.

---

Contact

Chijioke Edinburgh Jemanze

LinkedIn:
https://www.linkedin.com/in/chijioke-edinburgh-jemanze

GitHub:
https://github.com/EdinburghRay-cell

Email:
Edinburghray@gmail.com

---

Citation

If you reference this work in research or professional publications, please cite this repository appropriately.

---

© 2026 Chijioke Edinburgh Jemanze. All Rights Reserved.