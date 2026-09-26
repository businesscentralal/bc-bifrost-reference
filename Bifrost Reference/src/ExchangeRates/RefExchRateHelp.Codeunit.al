namespace Origo.Bifrost.Reference;

/// <summary>
/// Help ("use cards") for Reference.ExchangeRate.Get and Reference.ApiKey.Set.
/// Error texts are verbatim from the Labels in Ref Exch Rate Get Impl, Ref Rates Client and Ref Input.
/// </summary>
/// <remarks>Public document: returned to every caller. Contract only.</remarks>
codeunit 90027 "Ref Exch Rate Help"
{
    Access = Internal;

    procedure GetExchangeRateHelp(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Reference.ExchangeRate.Get');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Returns the latest reference exchange rate between two currencies from an external');
        Help.AppendLine('service (European Central Bank data, published once per working day).');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Read-only. Makes one outbound HTTPS call; writes nothing in Business Central.');
        Help.AppendLine('');
        Help.AppendLine('Not for Business Central''s own `Currency Exchange Rate` table - read that with');
        Help.AppendLine('`Data.Records.Get`. Not for historical rates.');
        Help.AppendLine('');
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `from` | text | yes | 3-letter ISO currency code, e.g. `EUR`. Case-insensitive. |');
        Help.AppendLine('| `to` | text | yes | 3-letter ISO currency code, different from `from`, e.g. `ISK`. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Reference.ExchangeRate.Get", "data": { "from": "EUR", "to": "ISK" } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "from": "EUR", "to": "ISK", "rate": 136.6, "rateDate": "2026-09-25", "source": "..." }');
        Help.AppendLine('```');
        Help.AppendLine('1 `from` = `rate` `to`. `rate` is a JSON number. `rateDate` is the day the rate was published');
        Help.AppendLine('(YYYY-MM-DD), which can be a few days before today around weekends and holidays.');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('| `error` (start) | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `Parameter ''from'' is required. Send it as text, for example "EUR".` | Missing. | Send `from` and `to`. |');
        Help.AppendLine('| `Parameter ''to'' is ''EURO''. Send a 3-letter ISO currency code, for example EUR or ISK.` | Not a 3-letter code. | Use ISO codes. |');
        Help.AppendLine('| `Parameters ''from'' and ''to'' are both EUR. Send two different currencies.` | Same currency. | Send two different codes. |');
        Help.AppendLine('| `The exchange rate service at ... could not be reached. If outbound HTTP is blocked, enable it for Bifrost Reference in the Bifrost Setup Wizard ...` | No network, or the sandbox blocks outbound HTTP for this app. | Run the Bifrost Setup Wizard and enable HTTP for Bifrost Reference. |');
        Help.AppendLine('| `The exchange rate service answered HTTP 404 for EUR to XYZ. ...` | The service does not know one of the currencies. | Use a currency the service supports. |');
        Help.AppendLine('| `The exchange rate service returned an answer without a rate for ISK. ...` | Unexpected answer. | Try again later; check Rates Base URL. |');
        Help.AppendLine('');
        Help.AppendLine('## Permissions and side effects');
        Help.AppendLine('No table permissions needed. If an API key is stored (see `Reference.ApiKey.Set`), it is sent');
        Help.AppendLine('in the `X-Api-Key` header; the default service needs no key.');
        Help.AppendLine('');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Reference.ApiKey.Set` - store an API key for the service.');
        exit(Help.ToText());
    end;

    procedure GetApiKeyHelp(): Text
    var
        Help: TextBuilder;
    begin
        Help.AppendLine('# Reference.ApiKey.Set');
        Help.AppendLine('');
        Help.AppendLine('## Overview');
        Help.AppendLine('Stores the API key the exchange rate service uses, in the Bifrost secret store.');
        Help.AppendLine('');
        Help.AppendLine('**Effect:** Commits. The key replaces any stored key for this company. The request body is');
        Help.AppendLine('redacted in the Bifrost message log straight after the key is read, so the key is never kept');
        Help.AppendLine('in plain text. It is never returned by any message type.');
        Help.AppendLine('');
        Help.AppendLine('People can do the same from Bifrost Setup > Apps > Bifrost Reference > Set API key.');
        Help.AppendLine('');
        Help.AppendLine('## Parameters');
        Help.AppendLine('| Key | Type | Required | Rules |');
        Help.AppendLine('| --- | --- | --- | --- |');
        Help.AppendLine('| `apiKey` | text, max 500 | yes | Not empty. |');
        Help.AppendLine('');
        Help.AppendLine('## Request example');
        Help.AppendLine('```json');
        Help.AppendLine('{ "type": "Reference.ApiKey.Set", "data": { "apiKey": "your-key" } }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Response');
        Help.AppendLine('```json');
        Help.AppendLine('{ "stored": true }');
        Help.AppendLine('```');
        Help.AppendLine('');
        Help.AppendLine('## Errors');
        Help.AppendLine('| `error` | Cause | Fix |');
        Help.AppendLine('| --- | --- | --- |');
        Help.AppendLine('| `Parameter ''apiKey'' is required. Send it as text, for example "your-key".` | Missing. | Send `apiKey`. |');
        Help.AppendLine('| `Parameter ''apiKey'' is empty. Send a value, for example "your-key".` | Empty. | Send the key. |');
        Help.AppendLine('');
        Help.AppendLine('## Permissions and side effects');
        Help.AppendLine('Needs write permission on `Ref Setup` (the app''s setup); other users do not see this type.');
        Help.AppendLine('');
        Help.AppendLine('## Related message types');
        Help.AppendLine('- `Reference.ExchangeRate.Get` - uses the key.');
        exit(Help.ToText());
    end;
}
