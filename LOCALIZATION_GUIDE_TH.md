# LOCAL MARS — Thai / English Localization

## Current interface mode

LOCAL MARS currently ships with an **English-only interface**. The language runtime in `i18n.js` initializes English, rejects attempts to switch to another language, and hides non-English language controls. This is intentional and matches the current product direction.

The Thai dictionary is retained in the repository for future localization work, but it is not currently selectable in the live interface. Do not describe Thai switching, browser-language detection, or persistent language preferences as active behavior until that feature is deliberately re-enabled and tested.

## Architecture

- `i18n.js`: English-only runtime, DOM translation helpers, dynamic-content observation, and date formatting.
- `locales/th.json`: retained Thai translation dictionary.
- `locales/en.json`: English dictionary.
- `sw.js`: caches the runtime and locale files for offline use.

Both locale files currently contain **751 matching translation IDs**. Every ID must exist in both files. Never renumber or reuse an existing ID.

## Add or update translations

When adding a translation, add the same new ID to both locale files:

```json
// locales/th.json
{ "LM0752": "ข้อความภาษาไทย" }
```

```json
// locales/en.json
{ "LM0752": "English text" }
```

Keep existing IDs unchanged. Update the service-worker cache version in `sw.js` when changing application assets.

For JavaScript-generated content, prefer the shared helper:

```js
const label = window.LOCAL_MARS_I18N?.t("ข้อความภาษาไทย", "English");
```

For date formatting:

```js
window.LOCAL_MARS_I18N?.formatDate(timestamp);
```

The helper currently returns English text because English is the only enabled interface language.

## Scope

The shared language runtime is loaded by:

- `index.html` — Planet Explorer
- `city.html` — City Builder
- `underground.html` — Underground Colony
- `m003-base.html` — M-003 Private Base
- `civilization.html` — Civilization Network

Localization is a presentation layer only. It does not create real-world ownership, deposits, digital assets, or payment balances.
