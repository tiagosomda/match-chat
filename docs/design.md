this was the original brainstorm / app spec done with claude chat.
there might be some outdated information. consider the other documents under docs as a more recent set of guidelines.


# World Cup Spoiler-Free Forum — Product Specification

## Overview

A web app built with Flutter and Firebase that allows users to discuss World Cup matches without spoilers. Scores, comments, and predictions are hidden by default and revealed independently per user. A global real-time chat is available alongside match-specific threaded comments. Access to commenting and chat requires an invite code. The app targets the 2026 FIFA World Cup.

---

## Tech Stack

- **Frontend:** Flutter (web target). Use the latest stable versions of Flutter and Dart at time of development.
- **Backend/Database:** Firebase Firestore (used for all data including real-time chat via Firestore listeners)
- **Authentication:** Firebase Auth
- **Hosting:** Firebase Hosting
- **Use the latest stable SDK versions** of all Firebase packages at time of development.

---

## Authentication & Access Tiers

There are two tiers of access:

### Tier 1 — Viewer (no invite code required)
- Can create an account via Firebase Auth — two supported methods: **email/password** and **Google Sign-In**
- Can browse the match list
- Can reveal scores, comments, and predictions independently
- Can view the global chat (with match-specific messages blurred per reveal state)
- Cannot post comments, chat messages, or submit predictions

### Tier 2 — Participant (invite code required)
- Has all Viewer permissions
- Can post comments on match threads
- Can send messages in the global chat
- Can submit score predictions before match start
- Unlocked by entering a valid invite code at any point after account creation

---

## Invite Code System

- Any Participant can generate invite codes from their profile
- Invite codes are unlimited per user
- Each code is a short alphanumeric string (e.g., 8 characters)
- Codes are single-use: once redeemed, they are marked as used and cannot be reused
- When a user redeems a code, their profile stores `invitedBy: userId` pointing to the code's generator
- This forms a tree structure useful for moderation: tracing bad actors back to their inviters
- There is no social graph, follow system, or friend mechanic beyond this invite relationship

### Firestore Structure — Invite Codes
```
inviteCodes/{codeId}
  code: string
  createdBy: userId
  usedBy: userId | null
  usedAt: timestamp | null
  createdAt: timestamp
```

---

## Data Model

### Users
```
users/{userId}
  displayName: string
  email: string
  isParticipant: bool
  isAdmin: bool
  invitedBy: userId | null
  createdAt: timestamp
```

### Matches
```
matches/{matchId}
  teamA: string
  teamB: string
  scheduledAt: timestamp
  stage: string              // e.g. "Group Stage", "Quarter-Final"
  group: string | null       // e.g. "Group A", null for knockout
  scoreA: int | null         // null until admin sets it
  scoreB: int | null
  status: string             // "upcoming" | "live" | "finished"
```

Matches are created and managed by admins manually via a simple admin interface.

### User Match State
Tracks each user's reveal state per match.
```
userMatchStates/{userId}_{matchId}
  userId: string
  matchId: string
  scoreRevealed: bool
  commentsRevealed: bool
  predictionsRevealed: bool
```

Document ID is the compound key `{userId}_{matchId}`.

### Comments
Asynchronous, persistent, tied to a specific match.
```
comments/{commentId}
  matchId: string
  userId: string
  displayName: string
  body: string
  createdAt: timestamp
```

Index by `matchId` + `createdAt`.

### Predictions
```
predictions/{predictionId}
  matchId: string
  userId: string
  displayName: string
  predictedScoreA: int
  predictedScoreB: int
  createdAt: timestamp
```

Predictions are locked once `matches/{matchId}.status` is set to `"live"` or `"finished"` by an admin.

Index by `matchId`.

### Chat Messages
A single global real-time chat stream. Messages may optionally be tagged to a specific match.
```
chatMessages/{messageId}
  userId: string
  displayName: string
  body: string
  matchId: string | null   // null = general message; set = tagged to a specific match
  createdAt: timestamp
```

Index by `createdAt`. All messages are queried as a single stream ordered by `createdAt`.

---

## Core Features

### Match List Screen
- Displays all matches sorted by `scheduledAt`
- Each match card shows:
  - Team names and flags (use a Flutter emoji flag package)
  - Match date and time (localized to user's timezone)
  - Stage / group label
  - Count of total comments (always visible, never hidden)
  - Indicator showing which users (invited by or who invited the current user) have revealed the score — shown as display names or initials
- Score is hidden behind a reveal toggle
- Tapping a match opens the Match Detail screen

### Match Detail Screen
Three independently revealable sections:

#### 1. Score Section
- Default: hidden, shows a "Reveal Score" button
- On reveal: displays final score. Updates `scoreRevealed: true` in `userMatchStates`
- Shows which users in the invite relationship have revealed the score (display names or initials)

#### 2. Predictions Section
- Default: hidden, shows a "Reveal Predictions" button
- On reveal: shows a list of all participant predictions (display name + predicted score)
- If match is upcoming and user is a Participant and has not yet predicted: show a prediction input (two number fields for score A and score B, submit button)
- Prediction input is locked once match status is "live" or "finished"
- Updates `predictionsRevealed: true` in `userMatchStates`

#### 3. Comments Section
- Default: hidden, shows a "Reveal Comments" button
- On reveal: shows comment feed sorted by `createdAt` ascending, with real-time updates via Firestore listener
- Participants see a comment input field at the bottom
- Viewers see a prompt to get an invite code to comment
- Updates `commentsRevealed: true` in `userMatchStates`

### Global Chat Screen
- Accessible from a persistent nav element (e.g., bottom bar or sidebar)
- Displays a single real-time stream of all chat messages, ordered by `createdAt`, using a Firestore real-time listener
- General messages (matchId: null) are always fully visible
- Match-tagged messages are blurred if the current user has not revealed either the score or comments for that match
  - If the user reveals either score or comments for that match, the message unblurs
  - The blur should indicate a match is referenced (e.g., show team names) without revealing message content
- **Composing a message:**
  - Text input field
  - Optional match dropdown to tag the message to a specific match (defaults to General)
  - Send button
- Only Participants can send messages; Viewers see a prompt to get an invite code

---

## Invite Reveal Indicator

The reveal indicator (on match cards and match detail) shows users from the current user's immediate invite relationship:
- The user who invited the current user (`invitedBy`)
- Users that the current user has invited (other users whose `invitedBy` points to current user)

This is purely derived from the invite tree. There is no follow system or separate friend graph.

---

## Admin Interface

A minimal admin screen (gated behind `isAdmin: bool` on the user document) that allows:
- Creating new matches (team names, scheduled time, stage, group)
- Editing match details
- Setting match status (`upcoming` → `live` → `finished`)
- Setting final scores (scoreA, scoreB)

Implemented as a simple form-based Flutter screen within the app, not a separate dashboard.

---

## Firestore Security Rules (Guidelines)

- `users`: readable by authenticated users, writable only by the owner or admin
- `matches`: readable by all authenticated users, writable only by admin
- `userMatchStates`: readable and writable only by the owning user
- `comments`: readable by all authenticated users, writable only by Participants (`isParticipant == true`)
- `predictions`: readable by all authenticated users, writable only by Participants and only before match goes live
- `inviteCodes`: creatable by Participants, readable for redemption lookup, updatable (mark as used) on redemption
- `chatMessages`: readable by all authenticated users, writable only by Participants

---

## UX & Design Notes

- The app is web-first via Flutter Web
- Mobile-responsive layout is required
- The visual theme should feel like a sports broadcast UI: dark background, bold typography, high contrast team displays
- The three reveal toggles (Score, Predictions, Comments) should be visually distinct and satisfying to interact with — not plain buttons
- Unrevealed sections should clearly communicate what is behind them (e.g., "12 comments" is always visible even when comments are hidden)
- Reveal indicators should show display names or initials, not just a count
- Blurred chat messages should visibly indicate which match they reference without revealing content

---

## Out of Scope (for this version)

- External score API integration (scores set manually by admin)
- Push notifications
- Nested/threaded comment replies
- Reactions or upvotes on comments
- Leaderboards or prediction scoring
- Native mobile app (iOS/Android) — web only
- Histogram or aggregate visualization of predictions
- Follow system or explicit friend graph beyond the invite tree

---

## Open Questions for Developer

- Determine latest stable Flutter, Dart, and Firebase SDK versions at time of development
- Choose an appropriate Flutter pub.dev package for emoji country flags
