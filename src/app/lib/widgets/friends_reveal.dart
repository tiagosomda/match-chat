import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/match.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';

/// A small tappable pill showing how many of the viewer's friends have revealed
/// a match's score. Tapping slides up a sheet listing who has and hasn't.
/// Renders nothing when the viewer has no friends.
class FriendsRevealBadge extends StatelessWidget {
  const FriendsRevealBadge({
    super.key,
    required this.match,
    required this.friendIds,
    required this.revealedFriendIds,
  });

  final MatchModel match;
  final List<String> friendIds;
  final Set<String> revealedFriendIds;

  @override
  Widget build(BuildContext context) {
    if (friendIds.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final count = revealedFriendIds.length;
    return InkWell(
      onTap: () => showFriendsRevealSheet(
        context,
        match: match,
        friendIds: friendIds,
        revealedFriendIds: revealedFriendIds,
      ),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, size: 13, color: c.accent),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: AppTheme.mono,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: c.accent,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              count == 1 ? 'friend' : 'friends',
              style: TextStyle(color: c.muted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showFriendsRevealSheet(
  BuildContext context, {
  required MatchModel match,
  required List<String> friendIds,
  required Set<String> revealedFriendIds,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FriendsRevealSheet(
      match: match,
      friendIds: friendIds,
      revealedFriendIds: revealedFriendIds,
    ),
  );
}

class _FriendsRevealSheet extends StatefulWidget {
  const _FriendsRevealSheet({
    required this.match,
    required this.friendIds,
    required this.revealedFriendIds,
  });

  final MatchModel match;
  final List<String> friendIds;
  final Set<String> revealedFriendIds;

  @override
  State<_FriendsRevealSheet> createState() => _FriendsRevealSheetState();
}

class _FriendsRevealSheetState extends State<_FriendsRevealSheet> {
  late Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().users.fetchByIds(widget.friendIds);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: c.lineStrong)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(c),
          Flexible(
            child: FutureBuilder<List<AppUser>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: c.accent),
                    ),
                  );
                }
                final friends = snap.data ?? const <AppUser>[];
                final revealed = friends
                    .where((u) => widget.revealedFriendIds.contains(u.id))
                    .toList();
                final hidden = friends
                    .where((u) => !widget.revealedFriendIds.contains(u.id))
                    .toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  children: [
                    _section(c, 'REVEALED', revealed, true),
                    if (revealed.isNotEmpty && hidden.isNotEmpty)
                      const SizedBox(height: 18),
                    _section(c, 'NOT YET REVEALED', hidden, false),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Friends',
                  style: TextStyle(
                    fontFamily: AppTheme.grotesk,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${widget.match.teamA} vs ${widget.match.teamB}',
                  style: TextStyle(color: c.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.line),
              ),
              child: Icon(Icons.close, size: 17, color: c.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    AppColors c,
    String label,
    List<AppUser> users,
    bool revealed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MonoLabel(
              '$label · ${users.length}',
              fontSize: 9.5,
              letterSpacing: 1.4,
            ),
          ],
        ),
        const SizedBox(height: 11),
        if (users.isEmpty)
          Text(
            revealed
                ? 'No friends have revealed yet.'
                : 'Everyone has revealed.',
            style: TextStyle(color: c.muted, fontSize: 12.5),
          )
        else
          for (final u in users) ...[
            Row(
              children: [
                Avatar(
                  name: u.displayName,
                  favoriteTeam: u.favoriteTeam,
                  size: 32,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    u.displayName,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  revealed
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16,
                  color: revealed ? c.accent : c.muted,
                ),
              ],
            ),
            const SizedBox(height: 13),
          ],
      ],
    );
  }
}
