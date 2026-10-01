# Navigation & State Audit (April 16, 2026)

## Fixed in this pass

1. **Wrong top-right route from chat entry**
   - Fixed by removing implicit discovery fallback in app bar action.
   - `DuoAppBar` now only executes explicit `onPeopleTap` callback.
   - File: `lib/features/people/presentation/duo_app_bar.dart`

2. **Slow/laggy partner switch UI**
   - Added optimistic update in `setActivePartner()` for immediate chat transition.
   - Rolls back state if backend update fails.
   - File: `lib/features/chat/application/duo_state_notifier.dart`

3. **Stale friend selector list**
   - Contact sheet data provider changed to `autoDispose` to avoid stale cached results.
   - Active partner now shown and disabled in selector list.
   - File: `lib/features/chat/presentation/contact_sheet.dart`

4. **Popup navigation reliability**
   - Profile popup now uses one navigator instance for `pop()` then `push()`.
   - File: `lib/features/profiles/presentation/profile_card_popup.dart`

## Manual verification matrix

### A) Chat / Partner selection
- Open `/chat` with no active partner.
- Tap top-right people icon.
- Expected: opens contact selector sheet (not discovery).

- Select a partner from contact sheet.
- Expected: immediate transition to chat for selected partner.

### B) Discovery / Requests
- Send request to a user.
- Expected: button disabled and visually changes to pending state.

- Accept request from Requests modal.
- Expected: friend appears in contacts and can be selected from chat people action.

### C) Unfriend state propagation
- Unfriend from profile popup.
- Expected:
  - Friends list refreshes.
  - Duo state refreshes.
  - If unfriended user was active partner, chat entry falls back to no-active state.

### D) Back navigation
- Discovery back arrow:
  - If pushed: pops previous screen.
  - If root tab: routes to `/chat`.

- Settings/Edit/Profile(push) back arrows should return cleanly.

## Remaining recommendation
- Add widget/integration tests for:
  1. Partner switch optimistic transition
  2. Request button disabled states
  3. Unfriend invalidation chain
  4. Discovery back behavior at root vs pushed contexts
