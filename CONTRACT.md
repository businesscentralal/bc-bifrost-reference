# The message type contract

Write this **before** the code, one per message type. Everything the caller sees is derived from it:

- the name
- the description, which is the **selection card**
- the help, which is the **use card**
- the input validation and error texts
- the break tests

## Why two cards

An agent uses a message type in two separate moments. Each needs different information.

| Moment | What the agent sees | What it needs | Card |
|---|---|---|---|
| **Selection:** "which of about 270 types do I call?" | name + one-line description | what it does, what it touches, how it differs from its siblings, the user's own words | Selection card |
| **First call:** "how do I call it right?" | the help document | how the target is identified, parameters and formats, preconditions, errors and their fixes | Use card |

Putting everything into the description makes selection worse. The text gets longer and hesitations increase, and facts that belong in the help drift out of date.

---

## Template

```
Name:            Area.Entity.Verb           (the user's words; the strongest search signal)
Effect:          Read-only | Commits | Rolled back | Irreversible
User words:      verbs and nouns users say for this, incl. synonyms (undo, fix, receive, totals …)
Siblings:        similar types and how to tell them apart
Ask the user when: situations where the agent should ask instead of guessing

Target:          how the record is identified, in order (subject GUID → subject No. → body key)
                 what "not given" answers, what "not found" answers
Parameters:      key | type | required | default | format / range
Preconditions:   status, setup, permission set, flags
Response:        fields with JSON types; what "nothing happened" looks like
Errors:          exact text (from the Label) | cause | fix
Repeat safety:   what a second identical call does
```

### Selection card: the description (`GetDescription`, ≤ 250 characters)

```
[Verb] [business object] [variants / what you get]. [Effect]. [Identified by …]. [Not for X – use Sibling.]
```

- Start with the outcome verb a user would say.
- Name the effect with one of the four fixed words.
- Say how the target is identified only if that distinguishes it from a sibling. Otherwise leave it to the help.
- Always give the boundary with the closest sibling.
- Never include:
  - codeunit or report numbers
  - internal jargon
  - the dotted name repeated

### Use card: the help (`GetMessageHelpAsMarkdownDocument`)

**Why the help matters most.** When a message type is offered to an agent as a tool, the tool schema is generic: a `type`, a `subject` and a request string. Nothing about your parameters, response or errors is in it. **The help is the only schema the caller gets.**

The rules:

- **Contract only.** Describe what the caller sends and gets. No implementation detail (codeunit or procedure names, `Codeunit.Run`, `TryFunction`, `Commit`), no infrastructure, no history ("this used to be called …"). Those belong in the XML doc comment.
- **Every section, every time,** even when the answer is "none". An empty Errors table tells the caller something; a missing section tells it nothing.
- **Change a Label and the help in the same commit.** Callers match on the exact error text.
- **Answer the repeat question in words.** There are three common answers:

  | Answer | Example | What the help says |
  |---|---|---|
  | Safe | `Legacy.Stock.CancelReservation` | A second call finds nothing, writes nothing and answers `"cancelled": false`. |
  | Fails on repeat | `Reference.Note.Add` | A second call with the same `no` gets the "already exists" error; after a timeout, treat that as "the first call went through". |
  | Repeat has an effect | `Legacy.Stock.Reserve` | Two identical calls reserve twice. Check with `Legacy.Stock.Get` when unsure. |

**Bad and good help for the same type:**

```markdown
# Legacy.Stock.Reserve
Reserves stock.
```

The agent doesn't know how to name the item, what the quantity rules are, what happens over stock, or whether a retry is harmless. It will guess.

```markdown
# Legacy.Stock.Reserve

## Overview
Reserves a quantity of one item in Legacy App. An existing reservation is increased;
otherwise one is created. Returns the new total.
**Effect:** Commits. **Not safe to repeat:** two identical calls reserve twice.

## Parameters
| Key | Type | Required | Rules |
| --- | --- | --- | --- |
| `itemNo` | text, max 20 | only if `subject` is empty | An existing, unblocked item. |
| `quantity` | number | yes | Greater than zero. |
| `allowOverStock` | true/false | no, default false | Send `true` only when the user agreed to reserve more than is in stock. |

## Errors
| `error` | Cause | Fix |
| --- | --- | --- |
| `Item 'X' does not exist. Check the number, or find the item with Data.Records.Get on table Item.` | Unknown item. | Check the number. |
| … every other Label, verbatim … | | |
```

This is shortened: the real document also has every other section below. The full version is `GetReserveHelp` in `Legacy App - Bifrost/src/LegacyAdapterHelp.Codeunit.al`.

**The sections.** This list is the one skeleton for every help document in this repository. Use these sections, in this order:

1. **Overview**, including the **Effect** line and *when not to use it*.
2. **Workflow**: which types come before and after.
3. **Identifying the target**: keys in order, and what "not given" and "not found" answer.
4. **Parameters**: a table with key, type, required, rules.
5. **Request example**: minimal and runnable.
6. **Response**: an example plus a field table with JSON types.
7. **Errors**: exact text, cause, fix. Copy the texts from the Labels.
8. **Safe retries / repeat**: one of the three answers above ("Read-only; safe to repeat" for a read).
9. **Permissions and side effects**.
10. **Formats and language**.
11. **Related message types**: only ones that exist.

---

## Worked example: `Reference.ServiceVisit.Create`

```
Name:            Reference.ServiceVisit.Create
Effect:          Commits
User words:      log a visit, register a service call, record time at a customer
Siblings:        time sheets / project journal lines (other apps) – this is a simple visit log
Ask the user when: the date is unclear ("last week")

Target:          customer – subject GUID → subject No. → body "customerNo"
                 not given → "No customer was given. Send the customer number in subject …"
                 not found → "Customer 'X' was not found. Check the number, or search …"
Parameters:      visitDate | date YYYY-MM-DD | yes | – | on or before work date
                 hours     | number        | yes | – | 0.25–24
                 description | text ≤100   | no  | '' |
                 externalId  | text ≤50    | no  | '' | makes retries safe
Preconditions:   customer not blocked for All; write permission on Ref Service Visit
Response:        { entryNo, created, customerNo, visitDate, hours, description, externalId }
                 created = false when externalId already existed (nothing written)
Errors:          (see RefVisitCreateHelp.Codeunit.al – copied from the Labels)
Repeat safety:   with externalId: safe. Without: each call creates a new visit.
```

The resulting selection card:

> Log a service visit at a customer: date, hours and a short description. Commits; safe to retry with the same externalId. Not for time sheets or project journal lines.

The resulting use card is in `Bifrost Reference/src/ServiceVisits/RefVisitCreateHelp.Codeunit.al`.

---

## Checking a contract

- **Selection:** write three ways a user would ask for this, one of them using a synonym. Does `find_message_types` rank the type first? If you can't deploy yet, give a fresh agent the description and its three closest siblings and ask it to choose.
- **First call:** give a fresh agent only the help and a request in plain words. Does it produce the exact working call?
- **Drift:** does every error in the help exist as a Label in the code, and every Label appear in the help?
