# Question guide

The goal is to check whether the user can **explain and defend** their own project. It is
not a trivia test. A good question makes them think "oh right, *that's* why". A bad one
makes them think "who remembers that?".

## Depth levels

| Level | Tests | Good example | Shape |
|---|---|---|---|
| `recall` | What was done | "Which library did we add for date parsing?" | Name the thing that was chosen or built |
| `understand` | Why it was done | "Why is the cache invalidated on write instead of on a timer?" | The reason behind a choice |
| `apply` | Consequences, transfer | "If two users edit the same row at once, what happens with the current lock strategy?" | A scenario run through the actual design |
| `challenge` | Critique, alternatives | "Which weakness of our retry logic would matter most at 10× traffic?" | The trade-off or weak point that matters most |

If the session only supports `recall` questions (e.g. a small config change), drop one level
down rather than making up deeper reasoning that never happened.

## Distractors

In order of preference:
1. **Alternatives that were really considered and rejected** in this session. These are the best.
2. **Common misconceptions** about how this kind of code or approach works.
3. **Nearby facts** from the same session that are true but answer a different question.

Avoid:
- Joke options or obviously absurd ones.
- "All of the above" or "None of the above".
- Options that differ by a single word, or only in wording.
- A correct option that is much longer or more qualified than the others.

## Grounding

- Every correct answer needs a source pointer: a file path, a commit SHA, or a decision you
  can point to in the conversation. If you can't name one, drop the question.
- Base questions on what the user saw or approved. Avoid internal details Claude handled
  silently unless they matter to how the project behaves.
- With a research session, ask what a conclusion rests on and what would change it, not
  about trivia from the sources.

## Bad → better

| Bad | Problem | Better |
|---|---|---|
| "On which line is `retryCount` defined?" | Gotcha with no understanding behind it | "What stops the retry loop from running forever?" |
| "What does REST stand for?" | Outside knowledge, not about this project | "Why did we return 409 instead of 400 for duplicate sign-ups?" |
| "Which is a good practice?" | Generic, and the answer is guessable | "Why does `saveDraft` debounce instead of saving on every keystroke?" |

## Explanations

Keep explanations to one line. Say *why* the correct answer is right, without repeating
the answer itself. Add the pointer in parentheses, e.g. `(src/cache.ts)`, `(a1b2c3d)` or
`(decision: chose SQLite over Postgres for local-only use)`.
