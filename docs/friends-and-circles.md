Originally this app deliberately had **no** social-graph features — the only
gate was the invite code, used for light moderation of who could use the app.

That changed with improvement #6 (see docs/improvements.md): a lightweight
**friends** feature now exists.

What we have now:
- From another user's profile you can mark them as a friend or clear it. The
  friend list is stored as an array of UIDs on your own user document
  (`match-chat/app/users/{uid}.friends`), so no extra collection or rule is
  needed beyond the existing "edit your own profile" permission.
- The match list and the match view show a counter of how many of your friends
  have **revealed the score** for that match. Tapping it opens a sheet listing
  which friends have revealed and which haven't. This reads per-user reveal
  state (`userMatchStates`), which is now world-readable to signed-in users —
  the docs only hold reveal booleans, never the score itself.

What we still deliberately **don't** have:
- No "circles", groups, or follower/following graph.
- No public activity feed beyond the friends-revealed counter above.
