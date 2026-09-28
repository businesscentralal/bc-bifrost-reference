# Legacy App: what "headless" means

Legacy App is an ordinary Business Central extension. It keeps one **stock reservation** per item and a **cancellation log**. It stands in for any app a partner already has.

Legacy App v2 is **headless inside, message types outside**: the business logic lives in the internal headless core `Legacy Stock API`, and the app's public API is its Bifröst message types (`Legacy.Stock.*`, in `src/MessageTypes/`). The app depends on Bifröst Foundation for that; the core itself knows nothing about Bifröst.

## What a person sees

Open **Legacy Stock Reservations** (search for it, or use page 90052). It is a list of items with their reserved quantity and three actions:

| Action | What happens on screen | What happens underneath |
|---|---|---|
| **Reserve stock...** | A dialog asks for the item and the quantity. Afterwards a message shows the new total. | `Legacy Stock API.Reserve(ItemNo, Quantity)` |
| **Cancel reservation** | A confirm dialog: "Cancel the reservation for 1896-S?" | `Legacy Stock API.CancelReservation(ItemNo)` |
| **Release all reservations** | "Release all 3 reservations?", then "3 reservations released." | `Legacy Stock API.CountReservations('')`, then `ReleaseReservations('')` |

When a reservation would exceed the inventory, **Reserve stock...** asks "Only 12 of item 1896-S is available to reserve. Reserve 20 anyway?" and passes your answer on as `AllowOverStock`.

## The idea: separate talking to a person from doing the work

Every action in a BC page does two different things:

1. **It talks to a person:** it opens a dialog, asks "are you sure?", shows a message, or reads the row the user has selected.
2. **It does the work:** it checks the rules and writes the data.

A person needs both. An **API, a job queue, another app or an AI agent needs only the second** and can't do the first: there is nobody to click OK. When the two are mixed in one procedure, nothing without a UI can use the app. That is what "not headless" means.

**Headless** means the work lives in procedures that never talk to a person:

- no `Confirm`, `Message`, `StrMenu` or dialogs
- no `Commit` in the middle
- every input as a parameter
- every outcome as a return value or a clear error

Pages call those procedures after talking to the person. Everything outside the app calls them through the app's message types.

```
             Person                      API · job queue · other app · AI agent
               │                                          │
   Page action (dialog, Confirm, Message)      Legacy.Stock.* message types
               │                               (public API: validated input,
               │                                audited, permission-checked)
               │                                          │
               └──────────────►  Legacy Stock API  ◄──────┘
                                 (internal headless core: rules + writes,
                                  no UI, no Commit, clear errors,
                                  explicit results, events)
```

In this app:

| | Talks to a person | Does the work |
|---|---|---|
| Reserve | the page action + `Legacy Reserve Dialog`, and the over-stock question | `Legacy Stock API.Reserve(ItemNo, Quantity, AllowOverStock)` returns the new total |
| Cancel | `Legacy Stock Mgt.CancelReservation` (Confirm, and a Message if there was nothing to cancel) | `Legacy Stock API.CancelReservation` returns true or false |
| Release all | `Legacy Stock Mgt.ReleaseAll` (count, Confirm, Message) | `Legacy Stock API.ReleaseReservations(ItemFilter)` returns the number released, in one transaction |
| Look up | the list page | `GetReservedQuantity`, `GetAvailableToReserve`, `WouldExceedInventory`, `CountReservations`, `HasReservation`, `IsReservable` |

Notice the reads. A page that must ask a question calls one (`WouldExceedInventory`, `CountReservations`), asks the person, and passes the answer to the facade. The facade never asks, and it never checks `GuiAllowed`.

## What it looked like before

The first version mixed the two in seven ways, all marked `AUDIT -` in `Legacy App v1 (not headless)/src/`:

- `Confirm` in the business procedures
- a stock check that ran only when there was a UI
- `Commit` between writes and after every row
- errors swallowed by `if Codeunit.Run`
- `exit(false)` and `Error('')` with no reason
- rules inside the page trigger
- a batch job with no filter

Each fix here is marked `FIXED -`. The table in [`START-HERE.md`](../START-HERE.md) §7.1 lists every pattern to look for.

One fix changes behaviour on purpose. In v1, code that called `ReserveStock` could reserve more than was in stock without a word, because only the UI path checked. Now every caller gets the check. Callers that really mean to over-reserve say so with `AllowOverStock`.

The old procedures in `Legacy Stock Mgt` still exist as thin shells, so existing callers keep working. [`START-HERE.md`](../START-HERE.md) §7 tells the story step by step.

## Message types are the public API

The core knows nothing about Bifröst, and it is `Access = Internal`: no other app can call it. The app's public API is its message types in `src/MessageTypes/`: `Legacy.Stock.Reserve`, `.CancelReservation`, `.Get`, `.List`, `.ReleaseAll` and the directory `Help.Legacy.Get`. They own only the Bifröst contract (read and check the input, call the core in isolation, answer); every business rule stays in the core.

Why message types rather than a public codeunit: every caller outside the app (other apps, integrations, the job queue, Orchestrator playbooks, agents) goes through the same validated, audited, permission-checked contract. The questions a person answers in dialogs have become explicit parameters (`allowOverStock`, `expectedCount`). The app's own pages call the core directly.

The old procedures in `Legacy Stock Mgt` stay public and obsolete, so existing callers keep working; new callers use the message types. Permission set **LEGACY STOCK** is the one assignable set; assign it together with Foundation's BIFROST permission sets.
