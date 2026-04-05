---
name: Karpathy's LLM Wiki pattern
description: Knowledge management pattern — LLM incrementally builds a persistent markdown wiki instead of RAG
type: reference
---

Source: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

## Core Idea

Instead of RAG (re-discovering knowledge every query), have the LLM **incrementally build and maintain a persistent wiki** — structured, interlinked markdown files. Sources are ingested once; the LLM reads, extracts, and integrates into existing pages.

## Three-Layer Architecture

1. **Raw sources** — immutable, curated documents (articles, papers, data files)
2. **The wiki** — LLM-generated markdown organized by summaries, entities, concepts, comparisons
3. **The schema** — configuration doc explaining structure, conventions, workflows

## Core Operations

- **Ingest** — process new source, discuss takeaways, write summary, update relevant pages, log the action
- **Query** — ask questions against the wiki; answers can be filed back as new pages
- **Lint** — periodic health checks for contradictions, stale claims, orphan pages, missing cross-refs

## Special Files

- `index.md` — content catalog with links, summaries, metadata by category
- `log.md` — append-only chronological record of ingests, queries, lint passes

## Tooling Tips

- Obsidian Web Clipper to convert articles to markdown
- Obsidian graph view for structure visualization
- `qmd` for local hybrid BM25/vector search with LLM re-ranking
- Git for version history

## Key Insight

"The tedious part of maintaining a knowledge base is not the reading or the thinking — it's the bookkeeping." LLMs handle the bookkeeping; humans curate sources and direct analysis.
