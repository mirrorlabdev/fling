# PTI — Post-Terminal Interface

> A direction worth exploring, not a manifesto.

## Problem

Fling solved the **input** side of terminal brokenness — CJK composition, emoji, clipboard management. But the **output** side remains untouched.

Terminals are rendering systems, not state systems. They draw characters on a grid. They don't know what a "progress bar" is, what "thinking" means, or where one tool's output ends and another begins. Everything is a stream of bytes decorated with ANSI escape codes.

This was fine when CLI output was simple. It's not fine anymore.

## Observation

LLM CLIs changed the nature of terminal output.

When you run `claude` or `codex`, the output isn't just text — it carries semantic structure:
- **Thinking** vs **response** vs **tool call** vs **tool result**
- Progress indicators, token counts, cost estimates
- Structured data (JSON, diffs, file trees) rendered as flat text
- Multi-turn context that the terminal forgets the moment it scrolls off

The terminal renders all of this identically: characters on a grid. The meaning is lost at the rendering layer.

Meanwhile, tools like Cursor and Windsurf prove that developers *want* structured AI output — they've just accepted that it requires a full IDE wrapper. But maybe it doesn't.

## Idea

What if we separate the layers that terminals currently collapse together?

```
[ Human ]
    |
[ Input Layer ]       <-- Fling (done)
    |
[ Runtime / CLI ]     <-- existing CLIs, unchanged
    |
[ Output Adapter ]    <-- intercept stdout, extract structure
    |
[ UI Renderer ]       <-- render structure as actual UI, not character grids
```

The key insight: **don't replace the CLI, layer on top of it.** The CLI doesn't need to change. The adapter reads its output and translates it into something a proper renderer can work with.

## Challenges

This is where it gets hard. Honestly, this might be where the idea dies.

**Every CLI speaks a different dialect.** There's no standard for "here's my progress" or "I'm thinking now." Each tool has its own ANSI patterns, its own spinners, its own way of clearing lines.

**ANSI parsing is a minefield.** Dozens of terminals interpret escape sequences differently. Building a robust parser that handles real-world output (not just spec-compliant output) is a known hard problem.

**Meaning extraction is fragile.** If you write a parser for Claude Code's output format and they change it next week, your parser breaks. This is the fundamental brittleness problem.

**Scope creep is the real enemy.** "Parse all CLI output" is an impossible goal. The temptation to generalize is strong and must be resisted.

## Practical Approach

Start absurdly narrow. Widen only when the narrow case works.

**Phase 1 — LLM CLI only.** Claude Code and similar tools have semi-structured output (markdown, tool boundaries, thinking blocks). Parse just these patterns. Everything else falls through to raw text.

**Phase 2 — JSON-native CLIs.** Many modern CLIs support `--output json` or similar flags. When available, use the structured output directly instead of parsing rendered text.

**Phase 3 — Fallback-first design.** Unknown output is displayed as-is, exactly like a terminal. The adapter enhances what it can parse and passes through what it can't. Zero degradation from the current experience.

**Phase 4 — Protocol.** If this direction proves useful, propose a lightweight structured output protocol for CLIs. This is the hardest and most speculative part. MCP (Model Context Protocol) is evolving in an adjacent direction — worth watching closely.

## Current State

| Phase | Description | Status |
|-------|------------|--------|
| Input Layer | Fling — independent floating input | **Done** |
| Output Adapter | LLM CLI stdout parser | Not started |
| UI Renderer | WPF-based structured display | Not started |
| Protocol | Standardized CLI output format | Far future |

The honest assessment: Phase 1 is done and useful on its own. Everything else is speculative. The output adapter is where this idea either proves itself or doesn't.

## What Would Make This Work

- **MCP expanding into output rendering** — the 2026 roadmap mentions moving beyond text-only interactions
- **LLM CLIs stabilizing their output formats** — or better, offering structured output flags
- **A small enough initial scope** — "enhance Claude Code output" is doable, "enhance all terminals" is not

## Philosophy

1. **Don't replace terminals** — layer on top
2. **Fallback is mandatory** — raw text is always available
3. **Narrow before wide** — one CLI well, not all CLIs badly
4. **Prove value before proposing standards** — build the adapter, then talk about protocols

---

*Started from Fling. Started from frustration. 2026-03-27.*
