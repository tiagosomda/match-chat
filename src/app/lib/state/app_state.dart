import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/app_user.dart';
import '../models/tournament.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/comment_service.dart';
import '../services/invite_service.dart';
import '../services/match_service.dart';
import '../services/prediction_service.dart';
import '../services/reveal_service.dart';
import '../services/seed_service.dart';
import '../services/tournament_service.dart';
import '../services/user_service.dart';

enum AppThemeMode { auto, light, dark }

/// Top-level navigation tabs.
enum AppTab { matches, chat, profile }

/// Holds session-wide state: the authenticated user, the active tournament, the
/// theme preference, and shared service instances.
class AppState extends ChangeNotifier {
  AppState({fb.FirebaseAuth? auth})
    : auth = AuthService(auth ?? fb.FirebaseAuth.instance) {
    _init();
  }

  // Services (shared across the app).
  final AuthService auth;
  final UserService users = UserService();
  final TournamentService tournaments = TournamentService();
  final MatchService matches = MatchService();
  final CommentService comments = CommentService();
  final PredictionService predictions = PredictionService();
  final ChatService chat = ChatService();
  final InviteService invites = InviteService();
  final RevealService reveals = RevealService();
  final SeedService seed = SeedService();

  // Auth / user state.
  fb.User? _firebaseUser;
  AppUser? _appUser;
  bool _loadingUser = false;
  StreamSubscription<fb.User?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;

  // Tournament state.
  List<Tournament> _allTournaments = <Tournament>[];
  Tournament? _tournament;
  bool _tournamentResolved = false;

  // Theme.
  AppThemeMode _themeMode = AppThemeMode.auto;
  static const _themeKey = 'themeMode';

  // Language. null = follow the device locale.
  Locale? _locale;
  static const _localeKey = 'localeCode';

  // Getters.
  fb.User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get isSignedIn => _firebaseUser != null;
  bool get isLoadingUser => _loadingUser;
  bool get isParticipant => _appUser?.isParticipant ?? false;
  bool get isAdmin => _appUser?.isAdmin ?? false;

  /// True when the session is an anonymous "browse as guest" session.
  bool get isGuest => _firebaseUser?.isAnonymous ?? false;
  String get displayName => _appUser?.displayName ?? 'You';

  List<Tournament> get allTournaments => _allTournaments;
  Tournament? get tournament => _tournament;
  bool get tournamentResolved => _tournamentResolved;
  String? get tournamentId => _tournament?.id;

  AppThemeMode get themeMode => _themeMode;

  /// The active locale override, or null to follow the device locale.
  Locale? get locale => _locale;

  /// The stored locale code ("en"/"es"/"pt"/"pt_BR"), or null for system.
  String? get localeCode =>
      _locale == null ? null : AppLocalizations.codeForLocale(_locale!);

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeKey);
    if (stored != null) {
      _themeMode = AppThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => AppThemeMode.auto,
      );
    }
    _locale = AppLocalizations.localeFromCode(prefs.getString(_localeKey));
    notifyListeners();

    _authSub = auth.authStateChanges().listen(_onAuthChanged);
  }

  /// Sets the app language. Pass null to follow the device locale.
  Future<void> setLocale(String? code) async {
    _locale = AppLocalizations.localeFromCode(code);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, code);
    }
  }

  Future<void> _onAuthChanged(fb.User? user) async {
    _firebaseUser = user;
    _userSub?.cancel();
    _userSub = null;

    if (user == null) {
      _appUser = null;
      _tournament = null;
      _tournamentResolved = false;
      notifyListeners();
      return;
    }

    _loadingUser = true;
    notifyListeners();

    try {
      final fallbackName = user.isAnonymous
          ? 'Guest'
          : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : (user.email?.split('@').first ?? 'Player'));
      await users.ensureUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: fallbackName,
      );

      // Live-watch the user document so participant/admin/profile changes
      // reflect immediately.
      _userSub = users.watch(user.uid).listen((appUser) {
        _appUser = appUser;
        _loadingUser = false;
        notifyListeners();
      });

      await _resolveTournament(user.uid);
    } catch (e) {
      _loadingUser = false;
      notifyListeners();
    }
  }

  Future<void> _resolveTournament(String uid) async {
    try {
      _allTournaments = await tournaments.fetchAll();
      final preferred = _appUser?.preferredTournamentId;
      _tournament = await tournaments.resolveInitial(preferred);
    } catch (_) {
      _tournament = null;
    }
    _tournamentResolved = true;
    notifyListeners();
  }

  /// Re-reads tournaments (e.g. after seeding) and picks the active one.
  Future<void> refreshTournaments() async {
    final uid = _firebaseUser?.uid;
    if (uid == null) return;
    await _resolveTournament(uid);
  }

  Future<void> selectTournament(Tournament t) async {
    _tournament = t;
    notifyListeners();
    final uid = _firebaseUser?.uid;
    if (uid != null) {
      await users.updatePreferredTournament(uid, t.id);
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Brightness resolveBrightness(Brightness platformBrightness) {
    switch (_themeMode) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.auto:
        return platformBrightness;
    }
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
