When adding localized strings that include a count, always use proper plural rules for each language.

For Swift (String Catalogs / .stringsdict):
- Use `.localizedStringWithFormat` or String Catalogs with plural variations
- Always provide `one` and `other` forms at minimum

For Hungarian (hu): nouns don't pluralize after numbers, but still provide plural forms for consistency.
For Romanian (ro): has a special "few" plural form for 2-19, but `one`/`other` covers most use cases.

Never use plain interpolation like `"\(count) items"` — it breaks for count=1.
