# License

This project is intended to be licensed under the **GNU General Public
License v3.0 (GPL-3.0)**.

Rather than paste a potentially-imperfect copy of the license text here,
grab the canonical, official version directly and save it as `LICENSE`
(no extension) in the repo root before your first public commit:

- Official text: https://www.gnu.org/licenses/gpl-3.0.txt
- GitHub will also auto-generate the correct file for you if you create the
  repo with the "Add a license" option and pick GPL-3.0 — this is the
  easiest, safest path.

Once `LICENSE` is in place, add the standard short-form notice to the top of
`README.md` and to `lib/main.dart`:

```
Nook — a private, local-first notes app.
Copyright (C) <year>  <your name>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
```

Also double check every dependency's own license before shipping — most of
the stack (MIT/BSD/Apache-2.0) is compatible with GPL-3.0 distribution, but
`appflowy_editor` is dual-licensed AGPL-3.0/MPL-2.0, which is worth reading
once yourself rather than taking a second-hand summary as final legal advice.
