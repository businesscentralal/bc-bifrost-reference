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
| `Dispatcher.Codeunit.al`, `License.Codeunit.al` | File paths *inside Foundation*, cited by `CALLING-FROM-AL.md`. Renamed by the documented rule ("the words Cloud Event / Cloud Events are removed"), but the Foundation repository is private and could not be read from here. |
| Foundation version `28.0.0.0` | Taken from `foundationMinVersion` in `data/apps.json` and from the DocEx map. If Foundation has moved past 28.0.0.0, raise it. |
| `.AL-Go/settings.json` dependency repo | Points at `OrigoSoftwareSolutions/bc-origo-bifrost-core`, from `tools/app-sources.json`. Private, unverified. |
| Object ID ranges 90000–90149 | Unchanged. They are sample ranges a partner would replace with their own, not Origo ranges — but confirm against the house standard before publishing. |
| The repository rename | `origo-bc-cloudevents-reference` → `bifrost-reference` is a GitHub setting. `QUICKSTART.md` and `app.json` already assume the new name. |

`resourceExposurePolicy` is left at `true` throughout, which is correct for a public
`businesscentralal` repository and is the whole point of a reference implementation.
