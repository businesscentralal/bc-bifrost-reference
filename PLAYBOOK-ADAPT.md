# Playbook C: adapt an existing app to Bifröst

You have an app, your own or someone else's, and you want its operations callable as Bifröst message types. You build a **separate adapter app** that depends on both the existing app and Bifrost Foundation. The existing app stays free of any Bifröst dependency.

Worked example: **Legacy App - Bifrost**, over **Legacy App**.

## Steps

### 1. Check that each operation is headless

Can it run without a dialog and without committing in the middle? If not, do Playbook B first: add a headless facade to the existing app.

`ADAPTING.md` walks through the case where it isn't headless (`Confirm` plus an early `Commit`) and why wrapping it as-is is unsafe.

### 2. Create the adapter app

- `app.json`: depend on the existing app, at the version that has the facade, and on Bifrost Foundation 28.0.0.0.
- Give it its own id range and namespace, e.g. `<Vendor>.<App>.Bifrost`.
- Register with the App Registry. Copy `LegacyAdapterRegistration.Codeunit.al`. Pass 0 as the setup page when the adapter has none.

### 3. Copy the input layer

Copy `LegacyAdapterInput.Codeunit.al`, which is a trimmed `Ref Input`. The split of responsibilities:

- **The adapter checks the shape:** missing, empty, wrong type, too long, number format.
- **The facade checks the business:** the item exists, it isn't blocked, the quantity is above zero.

Don't duplicate business rules in the adapter. They drift.

### 4. One message type per facade operation, plus the reads

| Facade | Message type | Effect |
|---|---|---|
| `Reserve` | `Legacy.Stock.Reserve` | Commits, not safe to repeat |
| `CancelReservation` | `Legacy.Stock.CancelReservation` | Commits, safe to repeat, `cancelled: true/false` |
| `GetReservedQuantity` / `HasReservation` | `Legacy.Stock.Get` | Read-only |

### 5. Call writes through an isolated Process codeunit

```al
ReserveProcess.SetReservation(ItemNo, Quantity);        // validated values
if Argument."Omit Commit" then
    ReserveProcess.Run(Argument)
else
    if not ReserveProcess.Run(Argument) then
        Argument.RespondWithError(GetLastErrorText()); // the facade's own actionable text
```

Any error the facade raises rolls back and comes back as `status = Error`. That's why the facade's error texts must be written for callers, not for developers.

### 6. Make outcomes explicit in the response

- If the facade returns a Boolean or a value, pass it on: `cancelled`, `totalReserved`.
- Never answer a no-op with the same response as a real change.

### 7. Set permissions and direction

- `IsEnabled` checks the permissions on the existing app's tables that the operation needs.
- The existing app should ship a permission set, as Legacy App does with `LEGACY STOCK`.
- Writes are `Inbound`; `Legacy.Stock.Get` is `Outbound`.

### 8. Write the contracts, help and tests

Same as for a new app: [CONTRACT.md](CONTRACT.md), [TESTING.md](TESTING.md). The help documents the facade's error texts verbatim.

## Adapting someone else's app

- Depend on the published app and use only its public API. You can't add a facade to it.
- **An operation is headless in the public API:** wrap it.
- **It isn't:** ask the owner for a headless procedure, or implement the operation against the app's tables in your adapter. Document that it bypasses the app's own logic.
- When a problem is in the underlying app, route it to that app's owner. Record the owner app in every test run, so gaps reach the right team.
