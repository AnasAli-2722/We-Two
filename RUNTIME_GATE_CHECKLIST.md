# Runtime Gate Checklist (Logic-First)

Use this checklist before UI polish releases.

## A) RPC Transition Matrix (Partner Requests)

### 1) Send request - success
- Search a user and tap **Add**.
- Expected:
  - Snackbar: `Request sent`
  - No error state in `discoveryStateProvider`

### 2) Send request - duplicate
- Send the same request twice.
- Expected:
  - Snackbar: `Request already exists.`
  - No crash, UI remains interactive

### 3) Accept request - success
- Open requests modal and tap **Accept**.
- Expected:
  - Snackbar: `Request accepted`
  - `duoStateProvider` refreshes
  - `friendsProvider` refreshes
  - user appears in friends list

### 4) Decline request - success
- Open requests modal and tap **Decline**.
- Expected:
  - Snackbar: `Request declined`
  - request removed from pending list

### 5) Stale request handling
- Accept/decline same request from another client first.
- Then perform action in this client.
- Expected:
  - Snackbar: `This request is no longer available.`
  - No crash

## B) Duo State Consistency

### 6) Contact switch
- Open contact sheet in chat and switch partner.
- Expected:
  - `duoStateProvider.activePartnerId` updates
  - message stream switches to selected partner

### 7) Unfriend active duo
- Unfriend currently active partner from profile popup.
- Expected:
  - active partner cleared when it matched removed friend
  - chat entry screen shows "Add friends to start chatting"

## C) Notification Lifecycle

### 8) Foreground message (active chat sender)
- Keep chat open with partner A and receive message from A.
- Expected: no local popup for message.

### 9) Foreground message (different sender)
- Keep chat open with partner A and receive message from B.
- Expected: local notification shown.

### 10) Tap routing
- Tap any push/local notification payload `/chat`.
- Expected: app routes to `/chat` reliably from foreground/background/cold start.

## D) Pass Criteria
- All scenarios above complete without exceptions.
- Analyzer clean: `flutter analyze`.
- No stale duo/friends/request UI after any action.
