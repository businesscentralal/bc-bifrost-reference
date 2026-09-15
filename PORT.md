# Port from Cloud Events to Bifröst

This repository was `businesscentralal/origo-bc-cloudevents-reference`. Everything here is the
same three apps with the platform retargeted from Origo Cloud Events Core to Bifröst Foundation.

Nothing in the business logic changed. The Legacy App's stock-reservation code is untouched
except for the one extraction that `ADAPTING.md` already documented.

## What the names were checked against

Not against memory, and not against the documentation alone. Three sources, in this order:

1. **`docs/iceland-docex/reference/object-id-map.md`** in the documentation repository — the
   rename map written when Iceland DocEx made this same move. It is the only authoritative
   record of which Foundation object replaced which Cloud Events object.
2. **The AL actually shipped** in `businesscentralal/bc-origo-bifrost-orchestrator`, which uses
   `Message Argument ori` 67 times, `Msg Interface ori` 43 times and `Msg Direction ori` 42
   times. Where the documentation and the shipped source disagreed, the source won.
3. **`docs/foundation/reference/`** for the API base and the event signatures.

| Cloud Events | Bifröst | Occurrences |
| --- | --- | --- |
| `Cloud Event Message Type ori` | `Message Type ori` | 8 |
| `Cloud Event Msg Interface ori` | `Msg Interface ori` | 13 |
| `Cloud Event Msg Direction ori` | `Msg Direction ori` | 11 |
| `CE Message Argument ori` | `Message Argument ori` | 19 |
| `ExecuteCloudEventTask` | `ExecuteBifrostTask` | 13 |
| `Cloud Events Dispatcher ori` | `Dispatcher ori` | 5 |
| `Cloud Event Message` (table) | `Message ori` | 2 |
| `CE Message Version ori` | `Message Version ori` | 3 |
| `Origo.APP.CloudEvents` | `Origo.Bifrost` | 8 |
| `Origo.CloudEvents.Reference` | `Origo.Bifrost.Reference` | 15 |

## The dependency is a different app, not a renamed one

This is the one change that is not a rename and is easy to get wrong.

```
- "id": "a629b897-7541-4562-bebb-c6122f15801c", "name": "Origo Cloud Events Core", "version": "28.1.0.0"
+ "id": "7505e808-6e52-4b96-a328-82573391297a", "name": "Bifrost Foundation",      "version": "28.0.0.0"
```

Foundation carries its own extension id. A search-and-replace on the name alone leaves the old
GUID in place, and the app then resolves against an extension that is not installed.

## Two things that deliberately were NOT renamed

`EXTENDING.md` and `INTEGRATING.md` still say **CloudEvents**, and that is correct. The
[CNCF CloudEvents specification](https://cloudevents.io/) is an external standard that the
message envelope draws on. It has nothing to do with the Origo product name, and renaming it
would produce a false sentence — the same trap that caught the first automated pass over the
documentation.

## What is not verified, and needs a person

| Item | Why |
| --- | --- |
| **It has never been compiled.** | No AL compiler and no Business Central container in this environment. Every identifier is verified by name against shipped source; none is verified by the compiler. |

## Checked against Foundation on 15 September, after this port was written

A session with access to the private `bc-origo-bifrost-core` read the real source. Three
results, recorded here because two of them correct this file.

| Claim | Verdict |
| --- | --- |
| `Dispatcher.Codeunit.al` / `"Dispatcher ori"`, `License.Codeunit.al` / `"License ori"` | **Right.** Codeunits 10078252 and 10077908. Foundation drops the product word rather than substituting it, which is what the rename rule predicted. |
| Foundation version `28.0.0.0` | **Right, and do not change it.** Foundation is exactly `28.0.0.0`. An earlier note here suggested raising it if symbols failed to download — that was a guess, it was wrong, and acting on it would have broken a correct pin. |
| `"CE Message Version ori"` | **Missed by this port.** Three occurrences survived in `CALLING-FROM-AL.md`, `QUICKSTART.md` and `AGENTS.md`. Now `"Message Version ori"` (enum 10077895). |

Other Foundation ids confirmed in passing: `Message Task ori` 10078251, `Secret Store ori`
10078305, `App Registry ori` 10078317.

### `CALLING-FROM-AL.md` was factually wrong, and it was wrong before the port

Inherited from the Cloud Events original, not introduced here. The file said `Execute()`
"calls the interface implementation directly. Nothing is persisted - no queue row, no
orchestration." Foundation's source says the opposite: every `Execute` overload delegates to
`EnqueueAndProcess`, which does `Insert(true)` and then `ProcessIncomingMessage(...)`, and the
codeunit declares `Permissions = tabledata "Message ori" = rim` for it.

Corrected here: a queue row **is** written, the orchestrator **does** run, only the webhook is
skipped (empty `TaskId`), and `Execute` passes `OmitCommit` = `true` while `EnqueueAndProcess`
defaults it to `false`. Two smaller corrections in the same file: `ResolvePool()` is `internal`
and no partner extension can call it, and the in-process MCP tool server moved out of the
kernel to Language Models.

**The same false claim is in Foundation's own `.claude/CLAUDE.md`** — *"Execute dispatches
straight through the interface (OmitCommit = true, no queue row)"*. That one has to be fixed in
the private repository; it is not in this port's reach.
| `.AL-Go/settings.json` dependency repo | Points at `OrigoSoftwareSolutions/bc-origo-bifrost-core`, from `tools/app-sources.json`. Private, unverified. |
| Object ID ranges 90000–90149 | Unchanged. They are sample ranges a partner would replace with their own, not Origo ranges — but confirm against the house standard before publishing. |
| The repository rename | `origo-bc-cloudevents-reference` → `bifrost-reference` is a GitHub setting. `QUICKSTART.md` and `app.json` already assume the new name. |

`resourceExposurePolicy` is left at `true` throughout, which is correct for a public
`businesscentralal` repository and is the whole point of a reference implementation.
