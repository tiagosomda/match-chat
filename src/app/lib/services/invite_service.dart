import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/invite_code.dart';
import 'firestore_refs.dart';

class InviteResult {
  InviteResult(this.ok, this.message);
  final bool ok;
  final String message;
}

class InviteService {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final _rng = Random.secure();

  String _generateCode() {
    return List.generate(
      8,
      (_) => _alphabet[_rng.nextInt(_alphabet.length)],
    ).join();
  }

  Stream<List<InviteCode>> watchMine(String uid) {
    return Refs.inviteCodes.where('createdBy', isEqualTo: uid).snapshots().map((
      snap,
    ) {
      final codes = snap.docs.map(InviteCode.fromDoc).toList();
      codes.sort((a, b) {
        final at = a.createdAt ?? DateTime(2000);
        final bt = b.createdAt ?? DateTime(2000);
        return bt.compareTo(at);
      });
      return codes;
    });
  }

  /// Generates a fresh unique invite code owned by [uid].
  Future<String> generate(String uid) async {
    // Retry a few times in the unlikely event of a collision.
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      final ref = Refs.inviteCode(code);
      final exists = (await ref.get()).exists;
      if (exists) continue;
      await ref.set(InviteCode(code: code, createdBy: uid).toCreateMap());
      return code;
    }
    throw Exception('Could not generate a unique code, please try again.');
  }

  Future<void> revoke(String code) {
    return Refs.inviteCode(code).delete();
  }

  /// Redeems a code: marks it used and promotes the redeemer to Participant,
  /// recording the invite relationship. Runs in a transaction so a code can
  /// only be claimed once.
  Future<InviteResult> redeem({
    required String rawCode,
    required String uid,
    required String displayName,
  }) async {
    final code = rawCode.trim().toUpperCase();
    if (code.length < 4) {
      return InviteResult(false, 'Enter a valid invite code.');
    }
    final codeRef = Refs.inviteCode(code);
    final userRef = Refs.user(uid);
    try {
      await Refs.db.runTransaction((tx) async {
        final codeSnap = await tx.get(codeRef);
        if (!codeSnap.exists) {
          throw _InviteError('That code does not exist.');
        }
        final data = codeSnap.data()!;
        if (data['usedBy'] != null) {
          throw _InviteError('That code has already been used.');
        }
        if (data['createdBy'] == uid) {
          throw _InviteError('You cannot redeem your own code.');
        }
        tx.update(codeRef, {
          'usedBy': uid,
          'usedByName': displayName,
          'usedAt': FieldValue.serverTimestamp(),
        });
        tx.update(userRef, {
          'isParticipant': true,
          'invitedBy': data['createdBy'],
        });
      });
      return InviteResult(true, 'Invite redeemed — welcome ⚽');
    } on _InviteError catch (e) {
      return InviteResult(false, e.message);
    } catch (_) {
      return InviteResult(false, 'Could not redeem code. Please try again.');
    }
  }
}

class _InviteError implements Exception {
  _InviteError(this.message);
  final String message;
}
