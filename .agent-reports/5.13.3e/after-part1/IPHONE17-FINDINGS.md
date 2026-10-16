# iPhone 17 Part 1 verification

- Device: iPhone 17 simulator, 402 × 874 points.
- Fixture: `otherDate` (Saturday, October 3), at default, AX1, and AX3.
- Default moon-card origin: `y = 199.3 pt`, exactly matching the before baseline (`199.3 pt`; delta `0.0 pt`).
- Default: no overlap.
- AX1: no visual overlap. The headline container now has a natural height of `176.0 pt`; the card starts at `y = 278.0 pt`.
- AX3: no visual overlap. The headline container now has a natural height of `272.7 pt`; the card starts at `y = 374.7 pt`.
- Long-city runtime coverage remains unavailable because the DEBUG screen fixture uses Irvine and its fake search service has no scripted suggestions.

Each screenshot has a matching `-hierarchy.txt` file in this directory.
