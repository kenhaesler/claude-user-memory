# Philosophy

The Agentic Substrate exists because agents write better software when they
are forced to slow down at the right moments. Four convictions shape
everything in this repository.

## 1. Truth Over Memory

A model's training data is stale the day it ships. Every implementation must
be grounded in current, version-accurate documentation — fetched, cited, and
verified — before any code is written. If the docs can't be found, that is a
finding to report, not a gap to fill from memory.

## 2. The Smallest Reversible Change

Plans touch the fewest files possible, prefer extension over modification,
and always ship with a rollback procedure. A change that cannot be undone
safely is not ready to be made. YAGNI and KISS are enforced at the planning
gate, not suggested in retrospect.

## 3. Verification at Every Step

Tests come first (RED → GREEN → REFACTOR), every plan step has a verification
command, and quality gates between phases block weak inputs instead of
letting them propagate. Retries are bounded: three attempts, then stop and
escalate with an honest report. An agent that loops is worse than an agent
that asks.

## 4. Knowledge Compounds

Patterns, decisions, and failure modes discovered during work are captured to
the project's `knowledge-core.md`, so the next session starts smarter than
the last. Context is curated, not hoarded: archive what's done, load what's
relevant, and keep the window high-signal.

## On Numbers

Earlier versions of this project quoted performance statistics from Anthropic
research posts as if they were guarantees of this system. They weren't, and
v5.0 removed them. The honest claim is structural: research-first workflows
fail less often at the moments that matter, and bounded, gated automation is
easier to trust than enthusiastic automation. (The v4-era document, statistics
and all, is preserved at `archive/history/PHILOSOPHY-v4.md`.)

---

*Research → Plan → Implement → Learn*
