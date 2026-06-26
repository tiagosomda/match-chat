# Invite System & Moderation

Match Chat is **invite-only by design**. Anyone can browse the schedule and
scores as a read-only guest, but **participating** — chatting, commenting and
making predictions — requires redeeming an invite code. This is the app's whole
moderation strategy, and it's deliberately low-tech.

## How it works

- **Browsing is open.** A guest (anonymous sign-in) can read everything. They
  can't post.
- **Participation is earned via a code.** Each existing participant can generate
  **single-use** invite codes and share them. Redeeming a valid code promotes
  the redeemer to *participant*.
- **Every invite is recorded.** When a code is redeemed:
  - the code stores who created it (`createdBy`) and who used it (`usedBy`),
  - the new participant's user doc stores `invitedBy` = the code's creator.

Those two fields turn the membership into a **tree**: the admin is the root, and
every participant hangs off whoever invited them.

```
admin
 ├── Alice            (invitedBy: admin)
 │    ├── Bob         (invitedBy: Alice)
 │    └── Carol       (invitedBy: Alice)
 └── Dave             (invitedBy: admin)
      └── Erin        (invitedBy: Dave)
```

## Why a tree helps moderation

The point isn't the codes — it's the **accountability chain** they create.

- **No anonymous participation.** There is no open sign-up that grants posting
  rights. A bot or a stranger can't just register and start spamming; someone
  with standing had to hand them a code.
- **Every bad actor is traceable.** If someone misbehaves — a bot, a spammer, or
  just an unpleasant person — you can see exactly who invited them, and who
  invited *that* person, all the way to the root.
- **You can prune a branch.** A bad actor rarely arrives alone. If one account
  is inviting bots or trolls, the whole sub-tree under it is suspect and can be
  removed together, not chased one-by-one.
- **Inviters self-select for quality.** Because your invites are attached to
  your name, people are careful about who they bring in — it's friends and
  family scale, by construction.

## What the admin can do

- Promote trusted people implicitly (they hold the root codes).
- Revoke any unused code they own.
- Delete any comment (spam/abuse cleanup).
- Read the invite tree (`createdBy` / `usedBy` / `invitedBy`) to find and remove
  a bad branch.

The result is a small, trusted, bot-resistant community without needing
heavyweight moderation tooling.
