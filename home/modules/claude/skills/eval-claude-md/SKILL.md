---
name: evaludate-claude-md
description: Measure the impact of a project's CLAUDE.md on exploration
efficiency.
---

# Evaluate CLAUDE.md effectiveness

Measure the impact of the project's CLAUDE.md on exploration efficiency by running controlled A/B experiments with subagents.

## Procedure

### Step 1: Derive representative tasks from recent PRs

Fetch the 50 most recent merged PRs using `gh pr list --state merged --limit 50 --json title,number,files`.

Classify them into categories by the area of the codebase they touch (e.g., "recipe changes", "test updates", "CI/workflow", "dev tooling", "build config"). Count PRs per category. Pick the **top 3 categories by frequency** and write one realistic exploration task prompt per category. Each task should be something a developer would actually ask Claude to help with — e.g., "Add a new X to Y", "Fix a failing test in Z", "Update the config for W".

Print a frequency table of all categories (with counts and percentages), then the 3 tasks you've chosen and which PR(s) inspired each one, before proceeding.

### Step 2: Run the "without CLAUDE.md" baseline

Temporarily rename `CLAUDE.md` to `CLAUDE.md.bak` so subagents won't have it in context.

Launch **3 agents in parallel** (one per task). Each agent gets this system prompt:

```

You are participating in an experiment measuring exploration costs. Your job is ONLY to explore and orient yourself — do NOT edit any files or read any CLAUDE.md files.

YOUR TASK: {task_description}

Do ONLY the exploration/orientation phase: understand the repo structure, find the relevant files, learn the conventions. Stop as soon as you could start the actual work.

Track every tool call. At the end, report:
1. Numbered list of every tool call (tool name, target, one-sentence finding)
2. Total tool call count
3. What information was the most difficult to find
```

Record the `tool_uses` and `total_tokens` from each agent's usage metadata.

### Step 3: Restore CLAUDE.md and run the "with" condition

Rename `CLAUDE.md.bak` back to `CLAUDE.md`.

Launch **3 agents in parallel** with the same tasks. Same prompt but replace the CLAUDE.md instruction with:

> You should have a CLAUDE.md file loaded in your context. Use it to skip exploration you don't need.

Record usage metadata again.

### Step 4: Report results

Present a comparison table:

```
| Task | Without (calls) | With (calls) | Saved | Without (tokens) | With (tokens) | Saved |
```

Then summarize:
- Which CLAUDE.md content had the highest impact (biggest reduction in exploration)
- Which content didn't help (tasks where exploration was similar)
- Recommendations: what to add, remove, or restructure in CLAUDE.md

If CLAUDE.md doesn't exist yet, skip step 2 and instead run the "without"
condition, then **draft** a CLAUDE.md based on what the agents needed most, and
run step 3 with the draft. End with recommendations.
