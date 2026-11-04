# LOCAL MARS — Thai / English Localization

The application uses one shared localization runtime across all main pages.

## Architecture

- `i18n.js`: language selection, DOM translation, dynamic-content observation, and formatting helpers.
- `locales/th.json`: Thai source strings.
- `locales/en.json`: matching English strings.
- `sw.js`: caches the runtime and both locale files for offline use.

The locale files use matching IDs (for example, `LM0001`). The current dictionary contains 702 matched entries. Never renumber or reuse an existing ID. Every ID must exist in both locale files.

## Language behavior

1. On the first visit, the app detects the browser language (Thai browsers start in Thai; others start in English).
2. The member can switch language with the header button.
3. The selection is saved in `localStorage` as `localMarsLanguage` and is shared across all LOCAL MARS pages on the same site.
4. Text nodes, placeholders, titles, accessible labels, and dynamically inserted interface content are translated.
5. Language changes do not modify member records, world data, construction data, or payment data.

## Add a translation

Add a new matching ID to both locale files:

```json
// locales/th.json
{ "LM0372": "ข้อความภาษาไทย" }
```

```json
// locales/en.json
{ "LM0372": "English text" }
```

Keep the same ID in both files. Then update the service-worker cache version in `sw.js` when changing application assets.

For JavaScript-generated content, prefer the shared helper:

```js
const label = window.LOCAL_MARS_I18N?.t("ภาษาไทย", "English");
```

For date formatting:

```js
window.LOCAL_MARS_I18N?.formatDate(timestamp);
```

## Scope

The shared language runtime is loaded by:

- `index.html` — Planet Explorer
- `city.html` — City Builder
- `underground.html` — Underground Colony
- `m003-base.html` — M-003 Private Base
- `civilization.html` — Civilization Network

Localization is a presentation layer only. It does not create real-world ownership, deposits, digital assets, or payment balances.
