# No AI slop: prose conventions overlay

Documentation baseline for prose work: READMEs, guides, doc comments meant for a human reader, PR descriptions, and anything else a prose-writing agent (for example the future `documentarian`) produces. The orchestrator injects this file the same way it injects `reference/typescript-conventions.md` and `reference/python-conventions.md` into code-writing agents. It is a baseline underneath the target repo's own doc conventions, never a replacement for them: a repo's own style guide, README template, or contributing doc wins wherever it speaks.

---

## Precedence: this is the baseline; the target repo's own conventions win

| Priority | Source |
|----------|--------|
| 1 | Session override from the user |
| 2 | Target repo's own doc conventions (style guide, README template, `CONTRIBUTING.md`, nearest `CLAUDE.md`) |
| 3 | This overlay |
| 4 | General good practice for prose |

---

## 1. Substance first: prove it, do not assert it

This is the top rule. Content-free confidence is the deepest tell a skeptical reader catches, and it is the first thing that gets a doc dismissed unread (source: https://luminousmen.substack.com/p/stop-feeding-me-ai-slop).

- **Every claim about how the tool behaves must be backed by a real artifact the reader can check**: a `file:line` reference to the code that does it, real captured command output, or a runnable example. Never describe behavior you have not verified from the source.
- **Concrete numbers beat adjectives.** The ripgrep README says "5-13x faster than grep" with a reproducible benchmark attached, never the bare word "fast" (source: https://codeant.ai/blogs/ripgrep-vs-grep-performance).
- **Prefer a runnable command with real captured output over a description of what it would show** (source: https://www.cesarsotovalero.net/blog/enhance-your-readme-with-asciinema.html).
- **Publish limitations and non-goals up front.** A tool that states its own blind spots reads as more credible, not less; hiding them reads as marketing (source: https://dev.to/debashish_ghosal/i-published-every-flaw-my-safety-tool-cant-catch-it-made-it-more-credible-not-less-57go).

## 2. Voice

Plain, literal, direct. Say what a thing does. Do not say that it is impressive, powerful, or amazing; let the numbers and the example carry that weight. If a sentence would sound the same in a product pitch and in an engineer's own notes, keep the engineer's version.

## 3. The do-not list (the tells)

**Banned words.** Individually some of these are ordinary English, but the model over-defaults to them at a density no human writer matches. Grep for density, not for a single hit: delve, leverage, robust, seamless, showcase, comprehensive, elevate, unlock, streamline, crucial, foster, underscore, tapestry, realm, navigate / navigating, pivotal, intricate, nuanced, multifaceted, landscape, testament, beacon, cornerstone, embark, groundbreaking. (sources: https://metric37.com/blog/common-ai-words-and-phrases , https://simplyhumanize.com/blog/words-chatgpt-overuses , https://ruben.substack.com/p/delve)

**Banned filler and transitions.** "it is worth noting that", "it is important to note", "in order to" (say "to"), "in today's fast-paced world", "when it comes to", "plays a crucial role in", "a wide range of", "in the realm of", "In conclusion", "Moreover", "Furthermore", "That being said", and the marketing closer "Whether you are X or Y, there is something for everyone." (sources: https://metric37.com/blog/common-ai-words-and-phrases , https://luminousmen.substack.com/p/stop-feeding-me-ai-slop)

**Punctuation.** No em dash. Skeptical readers filter on it even though the tell is folk wisdom more than a proven signal; treat it as a hard rule regardless (source: https://metric37.com/blog/common-ai-words-and-phrases). Use a comma, a colon, parentheses, or a plain period.

**Structural tells.**
- Rule-of-three padding: three bullets restating one point with different nouns, or a group of exactly three adjectives where one would do.
- "Not only X but also Y."
- A rhetorical question followed immediately by its own answer.
- A fake-thoroughness "alternatives considered" section that lists options with no real tie to a constraint the project actually hit.
- Uniform section scaffolding: every section the same shape and the same length regardless of how much there is to say about it.
(sources: https://luminousmen.substack.com/p/stop-feeding-me-ai-slop , https://metric37.com/blog/common-ai-words-and-phrases)

**Visual tells.** Emoji in headers or as decoration. Bolding scattered mid-sentence for emphasis rather than to mark a term. A badge wall; cap at three to five badges that each carry real information (build status, version, license), not a row of decoration. (sources: https://gingiris.github.io/growth-tools/blog/2026/04/02/github-readme-template-guide/ , https://repoclip.io/blog/how-to-write-a-github-readme)

## 4. The do list (what earns trust)

- Distill real thinking a reader could not get anywhere else: a constraint the project actually hit, a dead end it walked into, a tradeoff it chose and why (source: https://luminousmen.substack.com/p/stop-feeding-me-ai-slop).
- Concrete numbers with the method that produced them, and real command output over paraphrase.
- Limitations stated up front, not buried at the bottom or omitted.
- Show, don't tell: a real example the reader can run beats a paragraph describing what running it would feel like.
- Restraint. The first screenful answers what the tool is, why it exists, and how to run it, then stops. Everything else can wait past the fold (source: https://www.freecodecamp.org/news/how-to-write-a-good-readme-file/).

## 5. Extra scrutiny for AI-adjacent tools

A self-run benchmark for an AI tool is assumed rigged until proven otherwise; do not write a claim that flatters the tool being documented off a number the same team produced. Publish the method (what was measured, on what data, with what baseline) alongside the number, and state the scope honestly rather than picking the framing that looks best. (sources: https://deepsource.com/blog/ai-code-review-benchmarks , https://chatgpt.ca/blog/github-fake-stars-ai-tool-evaluation)

## 6. The caveat that keeps it honest

Do not overcorrect into performing "humanness": a folksy aside, a deliberately quirky turn of phrase, or a joke dropped in to sound less machine-written is its own tell, and a reader who has seen that trick trusts it even less than plain slop. Substance is what actually carries credibility here: real numbers, runnable output, honest non-goals, and claims that cite where they came from. Plain prose is the vehicle for that substance, not a costume worn on top of a thin doc (source: https://luminousmen.substack.com/p/stop-feeding-me-ai-slop).

## 7. Mandatory self-check before returning

Run this against your own draft before you send it. Do not skip an item because the draft "reads fine."

- [ ] Every claim about the tool's behavior traces to a `file:line` or to real captured output. No asserted behavior.
- [ ] Any performance or hit-rate number shown was actually measured, with the method stated. No invented figures.
- [ ] Grep-scan the draft for the banned words and filler in Section 3. Remove each hit, or justify it inline if it is genuinely load-bearing (a proper noun, a quoted source, a term of art the target repo already uses).
- [ ] Zero em dashes.
- [ ] No emoji in headers. At most five informative badges, none decorative.
- [ ] The opening (before the first fold) would get a skeptical senior engineer to keep reading: a real demo or real output, not a pitch.

```bash
# Quick grep pass for the self-check, adapt paths to the changed files
grep -noE 'delve|leverage|robust|seamless|showcase|comprehensive|elevate|unlock|streamline|crucial|foster|underscore|tapestry|realm|navigat(e|ing)|pivotal|intricate|nuanced|multifaceted|landscape|testament|beacon|cornerstone|embark|groundbreaking' <changed .md files>
grep -noE 'it is (worth|important) to note|in order to|when it comes to|plays a crucial role|a wide range of|in the realm of|^In conclusion|^Moreover|^Furthermore|That being said' <changed .md files>
grep -c '—' <changed .md files>
```

If the target repo's own doc conventions name additional banned words or a different em-dash policy, that repo's rule wins; add its patterns to the same grep pass for that repo.
