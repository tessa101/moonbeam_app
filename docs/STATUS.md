# Status & Handoff

> A living note on where things stand. Update it at the end of each work session
> so the next session (you, or Claude) can pick up cold.

_Last updated: 2026-09-23_

## Where things live
- **Local repo:** `~/app-ideas/moonbeam` (the one true folder)
- **GitHub:** https://github.com/tessa101/moonbeam_app (`main`)
- **Xcode project:** `moonbeam-app/moonbeam-app.xcodeproj` (SwiftUI template, no test target yet)
- Don't tick "Create Git repository" in Xcode. This folder already has one.

## Done
- Planning docs: PRODUCT, ARCHITECTURE, ASTRONOMY, DECISIONS, CLAUDE.md
- Xcode project created inside the repo, plus a `.gitignore`
- Astronomy Engine sanity check (JS, Mar Vista, 2026-09-23): rise 5:18 PM 105° ESE · set 3:37 AM 252° WSW · 91% illuminated

## Next
1. [x] Push to GitHub (docs + Xcode project are on `main`)
2. [ ] Astronomy Engine spike: vendor `astronomy.c/.h`, bridging header, print the moon table for a hardcoded city
3. [ ] Add a test target and pull USNO reference values (run from the Mac; the cloud sandbox can't reach USNO)
4. [ ] Build the SwiftUI table

## Open questions
- Minimum iOS version (suggested 26+)
- Show illumination for the current time or for local midnight?
- Primary persona (confirm with design partner)
- Display name "Moonbeam" (project name is `moonbeam-app`)
