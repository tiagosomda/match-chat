import 'package:flutter/material.dart';

/// Hand-rolled localization for Match Chat.
///
/// Strings are looked up by key with a fallback chain so partial translations
/// degrade gracefully: pt_BR → pt → en, pt → en, es → en, en. Use
/// `context.l10n.t('key')` for plain strings and `tp('key', {...})` for ones
/// with `{placeholders}`.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Locales the app ships translations for. `pt` is European Portuguese;
  /// `pt_BR` is Brazilian. A device set to `pt_PT` resolves to `pt`.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
    Locale('pt', 'BR'),
  ];

  /// The languages offered in the in-app picker (value stored in prefs/profile).
  /// `null` (system default) is handled by the picker UI separately.
  static const List<({String code, String label})> pickable = [
    (code: 'en', label: 'English'),
    (code: 'es', label: 'Español'),
    (code: 'pt', label: 'Português (Portugal)'),
    (code: 'pt_BR', label: 'Português (Brasil)'),
  ];

  /// Parses a stored code ("en", "es", "pt", "pt_BR") into a Locale.
  static Locale? localeFromCode(String? code) {
    switch (code) {
      case 'en':
        return const Locale('en');
      case 'es':
        return const Locale('es');
      case 'pt':
        return const Locale('pt');
      case 'pt_BR':
        return const Locale('pt', 'BR');
      default:
        return null;
    }
  }

  /// The inverse of [localeFromCode].
  static String codeForLocale(Locale locale) {
    if (locale.languageCode == 'pt') {
      return locale.countryCode == 'BR' ? 'pt_BR' : 'pt';
    }
    return locale.languageCode;
  }

  String get _key => codeForLocale(locale);

  String t(String key) {
    switch (_key) {
      case 'pt_BR':
        return _ptBR[key] ?? _pt[key] ?? _en[key] ?? key;
      case 'pt':
        return _pt[key] ?? _en[key] ?? key;
      case 'es':
        return _es[key] ?? _en[key] ?? key;
      default:
        return _en[key] ?? key;
    }
  }

  String tp(String key, Map<String, String> params) {
    var s = t(key);
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

// ---------------------------------------------------------------------------
// English — the source of truth (every key lives here).
// ---------------------------------------------------------------------------
const Map<String, String> _en = {
  // nav
  'navMatches': 'Matches',
  'navChat': 'Chat',
  'navProfile': 'Profile',
  // common
  'signIn': 'Sign in',
  'signOut': 'Sign out',
  'save': 'Save',
  'cancel': 'Cancel',
  'createAccount': 'Create account',
  'email': 'Email',
  'password': 'Password',
  // landing
  'taglineSpoilerFree': 'WORLD CUP 2026 · SPOILER-FREE',
  'strengthScheduleTitle': 'Spoiler-free schedule',
  'strengthScheduleDesc':
      'Scores, comments and predictions stay hidden until you choose to reveal them.',
  'strengthFriendsTitle': 'See which friends have watched',
  'strengthFriendsDesc':
      'Know who has already seen a match — without giving the result away.',
  'browseMatches': 'Browse matches',
  'signInOrCreate': 'Sign in or create account',
  'browseReadOnly':
      'Browsing is read-only. An invite code unlocks chat & predictions.',
  'continueWithGoogle': 'Continue with Google',
  'orLabel': 'OR',
  'alreadyHaveAccount': 'Already have an account? ',
  'newHere': 'New here? ',
  'createAnAccount': 'Create an account',
  // matches list
  'searchHint': 'Search teams or stage…',
  'filterAll': 'All',
  'filterUpcoming': 'Upcoming',
  'filterLive': 'Live',
  'filterFinished': 'Finished',
  'filterArchived': 'Archived',
  'shownCount': '{n} SHOWN',
  'noMatchesSearch': 'No matches match your search.',
  'couldNotLoadMatches': 'Could not load matches.',
  'startsIn': 'Starts in {time}',
  'statusUpcoming': 'UPCOMING',
  'statusLive': '● LIVE',
  'statusFullTime': 'FULL TIME',
  'archivedUpper': 'ARCHIVED',
  'hiddenUpper': 'HIDDEN',
  // match detail
  'archiveUpper': 'ARCHIVE',
  'restoreUpper': 'RESTORE',
  'editUpper': 'EDIT',
  'matchNotFound': 'Match not found.',
  'yourLocalTime': 'YOUR LOCAL TIME ({tz})',
  'reveal': 'Reveal',
  'hideUpper': 'HIDE',
  'predictions': 'Predictions',
  'comments': 'Comments',
  'goalsCount': '{n} GOALS',
  'revealGoals': 'Reveal goals',
  'goalsTapScorers': 'GOALS · TAP TO SEE SCORERS',
  'scorersTapHide': 'SCORERS · TAP TO HIDE NAMES',
  'friendSingular': 'friend',
  'friendPlural': 'friends',
  // country schedule & results (#7)
  'viewMatchesUpper': 'MATCHES',
  'scheduleResultsUpper': 'SCHEDULE & RESULTS',
  'played': 'Played',
  'teamMatchesCount': '{n} MATCHES',
  'noTeamMatches': 'No matches for {team} yet.',
  'homeShort': 'HOME',
  'awayShort': 'AWAY',
  'vsOpponent': 'vs {team}',
  // predictions
  'yourPrediction': 'Your prediction',
  'updateYourPrediction': 'Update your prediction',
  'predict': 'Predict',
  'update': 'Update',
  'cancelUpper': 'CANCEL',
  'editUpperShort': 'EDIT',
  'deleteUpper': 'DELETE',
  'yourPredictionIsIn': 'Your prediction is in',
  'everyonesPredictions': "EVERYONE'S PREDICTIONS",
  'noPredictionsYet': 'No predictions yet.',
  'enterBothScores': 'Enter both scores',
  'predictionSubmitted': 'Prediction submitted ✅',
  'predictionUpdated': 'Prediction updated ✅',
  'predictionRemoved': 'Prediction removed',
  'couldNotSubmit': 'Could not submit: {e}',
  'couldNotRemove': 'Could not remove: {e}',
  'invitePredictionPrompt': 'Get an invite code to add your prediction →',
  'predictionsHidden': '{n} PREDICTIONS HIDDEN',
  'revealPredictions': 'Reveal predictions',
  'predictionsLocked': 'Predictions locked',
  'predictionsLockedLiveDesc':
      'The match has kicked off — predictions are closed.',
  'predictionsLockedOverDesc':
      'This match is over — predictions are closed.',
  // comments
  'revealComments': 'Reveal comments',
  'commentsHidden': '{n} COMMENTS HIDDEN',
  'noCommentsYet': 'No comments yet — be the first.',
  'addComment': 'Add a comment…',
  'replyHint': 'Reply…',
  'replyUpper': '↳ REPLY',
  'replyButton': 'Reply',
  'postButton': 'Post',
  'editComment': 'Edit comment…',
  'commentDeletedByUser': 'Comment deleted by user',
  'commentDeletedByAdmin': 'Comment deleted by admin',
  'editedTag': '· EDITED',
  'inviteCommentPrompt': 'Get an invite code to join the conversation →',
  'deleteCommentTitle': 'Delete comment?',
  'deleteCommentBodyUser':
      'This will replace it with “deleted by user”. Replies stay.',
  'deleteCommentBodyAdmin':
      'This will replace it with “deleted by admin”. Replies stay.',
  'delete': 'Delete',
  'couldNotPost': 'Could not post: {e}',
  'couldNotSave': 'Could not save: {e}',
  'couldNotDelete': 'Could not delete: {e}',
  // chat
  'globalChatLive': 'GLOBAL CHAT · LIVE',
  'noMessagesYet': 'No messages yet — say hello 👋',
  'postTo': 'POST TO',
  'generalEveryone': '🌐 General (everyone)',
  'messageEveryone': 'Message everyone…',
  'messageAboutMatch': 'Message about this match…',
  'send': 'Send',
  'inviteChatPrompt': 'Get an invite code to join the chat →',
  'revealMatchToRead': 'Reveal match to read',
  'postingTo': 'Posting to {match}',
  'couldNotSend': 'Could not send: {e}',
  // profile
  'displayNameLabel': 'DISPLAY NAME',
  'yourName': 'Your name',
  'displayNameHint': 'How you appear in chat, comments and predictions.',
  'nameUpdated': 'Name updated',
  'favoriteTeam': 'Favorite team',
  'favoriteTeamHint': 'Your flag becomes your avatar across the app.',
  'noFavoriteTeam': 'No favorite team',
  'favoriteTeamSet': 'Favorite team set',
  'favoriteTeamCleared': 'Favorite team cleared',
  'haveInviteCode': 'Have an invite code?',
  'redeemDesc': 'Unlock commenting, chat & predictions. Codes are single-use.',
  'redeem': 'Redeem',
  'appearance': 'Appearance',
  'themeAuto': 'Auto',
  'themeLight': 'Light',
  'themeDark': 'Dark',
  'openOnLaunch': 'Open on launch',
  'openOnLaunchHint': 'Where the app opens when you come back.',
  'lastPage': 'Last page',
  'language': 'Language',
  'languageSystem': 'System default',
  'inviteCodes': 'Invite codes',
  'newCode': 'New code',
  'matchAdmin': 'Match admin',
  'matchAdminDesc': 'Create, schedule & edit matches',
  'tierParticipant': 'PARTICIPANT',
  'tierViewer': 'VIEWER',
  'guestSession': 'Guest session',
  'browsingAsGuest': 'Browsing as guest',
  'guestCardDesc':
      'Create an account to comment, chat and make predictions. Your guest reveals stay on this device only.',
  'signInCreateAccount': 'Sign in / Create account',
  // user profile
  'profileUpper': 'PROFILE',
  'userNotFound': 'User not found.',
  'addFriend': 'Add friend',
  'friendTapRemove': 'Friend · tap to remove',
  'addedToFriends': 'Added to friends',
  'removedFromFriends': 'Removed from friends',
  'supports': 'Supports',
  // friends sheet
  'friends': 'Friends',
  'revealedUpper': 'REVEALED',
  'notYetRevealed': 'NOT YET REVEALED',
  'noFriendsRevealed': 'No friends have revealed yet.',
  'everyoneRevealed': 'Everyone has revealed.',
  // no tournament
  'noTournamentsYet': 'No tournaments yet',
  'noTournamentAdmin': 'Seed the sample World Cup 2026 data to get started.',
  'noTournamentViewer': 'Check back soon — an admin needs to set things up.',
  'seedSampleData': 'Seed sample data',
};

// ---------------------------------------------------------------------------
// Spanish
// ---------------------------------------------------------------------------
const Map<String, String> _es = {
  'navMatches': 'Partidos',
  'navChat': 'Chat',
  'navProfile': 'Perfil',
  'signIn': 'Iniciar sesión',
  'signOut': 'Cerrar sesión',
  'save': 'Guardar',
  'cancel': 'Cancelar',
  'createAccount': 'Crear cuenta',
  'email': 'Correo',
  'password': 'Contraseña',
  'taglineSpoilerFree': 'MUNDIAL 2026 · SIN SPOILERS',
  'strengthScheduleTitle': 'Calendario sin spoilers',
  'strengthScheduleDesc':
      'Los resultados, comentarios y pronósticos quedan ocultos hasta que decidas mostrarlos.',
  'strengthFriendsTitle': 'Mira qué amigos ya lo vieron',
  'strengthFriendsDesc':
      'Descubre quién ya vio un partido, sin revelar el resultado.',
  'browseMatches': 'Ver partidos',
  'signInOrCreate': 'Inicia sesión o crea una cuenta',
  'browseReadOnly':
      'La navegación es de solo lectura. Un código de invitación desbloquea el chat y los pronósticos.',
  'continueWithGoogle': 'Continuar con Google',
  'orLabel': 'O',
  'alreadyHaveAccount': '¿Ya tienes una cuenta? ',
  'newHere': '¿Primera vez aquí? ',
  'createAnAccount': 'Crear una cuenta',
  'searchHint': 'Busca equipos o fase…',
  'filterAll': 'Todos',
  'filterUpcoming': 'Próximos',
  'filterLive': 'En vivo',
  'filterFinished': 'Finalizados',
  'filterArchived': 'Archivados',
  'shownCount': '{n} VISIBLES',
  'noMatchesSearch': 'Ningún partido coincide con tu búsqueda.',
  'couldNotLoadMatches': 'No se pudieron cargar los partidos.',
  'startsIn': 'Empieza en {time}',
  'statusUpcoming': 'PRÓXIMO',
  'statusLive': '● EN VIVO',
  'statusFullTime': 'FINAL',
  'archivedUpper': 'ARCHIVADO',
  'hiddenUpper': 'OCULTO',
  'archiveUpper': 'ARCHIVAR',
  'restoreUpper': 'RESTAURAR',
  'editUpper': 'EDITAR',
  'matchNotFound': 'Partido no encontrado.',
  'yourLocalTime': 'TU HORA LOCAL ({tz})',
  'reveal': 'Mostrar',
  'hideUpper': 'OCULTAR',
  'predictions': 'Pronósticos',
  'comments': 'Comentarios',
  'goalsCount': '{n} GOLES',
  'revealGoals': 'Mostrar goles',
  'goalsTapScorers': 'GOLES · TOCA PARA VER GOLEADORES',
  'scorersTapHide': 'GOLEADORES · TOCA PARA OCULTAR',
  'friendSingular': 'amigo',
  'friendPlural': 'amigos',
  'viewMatchesUpper': 'PARTIDOS',
  'scheduleResultsUpper': 'CALENDARIO Y RESULTADOS',
  'played': 'Jugados',
  'teamMatchesCount': '{n} PARTIDOS',
  'noTeamMatches': 'Aún no hay partidos de {team}.',
  'homeShort': 'LOCAL',
  'awayShort': 'VISITA',
  'vsOpponent': 'vs {team}',
  'yourPrediction': 'Tu pronóstico',
  'updateYourPrediction': 'Actualiza tu pronóstico',
  'predict': 'Pronosticar',
  'update': 'Actualizar',
  'cancelUpper': 'CANCELAR',
  'editUpperShort': 'EDITAR',
  'deleteUpper': 'ELIMINAR',
  'yourPredictionIsIn': 'Tu pronóstico está hecho',
  'everyonesPredictions': 'PRONÓSTICOS DE TODOS',
  'noPredictionsYet': 'Aún no hay pronósticos.',
  'enterBothScores': 'Ingresa ambos marcadores',
  'predictionSubmitted': 'Pronóstico enviado ✅',
  'predictionUpdated': 'Pronóstico actualizado ✅',
  'predictionRemoved': 'Pronóstico eliminado',
  'couldNotSubmit': 'No se pudo enviar: {e}',
  'couldNotRemove': 'No se pudo eliminar: {e}',
  'invitePredictionPrompt':
      'Consigue un código de invitación para añadir tu pronóstico →',
  'predictionsHidden': '{n} PRONÓSTICOS OCULTOS',
  'revealPredictions': 'Mostrar pronósticos',
  'predictionsLocked': 'Pronósticos bloqueados',
  'predictionsLockedLiveDesc':
      'El partido ya comenzó — los pronósticos están cerrados.',
  'predictionsLockedOverDesc':
      'Este partido terminó — los pronósticos están cerrados.',
  'revealComments': 'Mostrar comentarios',
  'commentsHidden': '{n} COMENTARIOS OCULTOS',
  'noCommentsYet': 'Aún no hay comentarios — sé el primero.',
  'addComment': 'Añade un comentario…',
  'replyHint': 'Responder…',
  'replyUpper': '↳ RESPONDER',
  'replyButton': 'Responder',
  'postButton': 'Publicar',
  'editComment': 'Edita el comentario…',
  'commentDeletedByUser': 'Comentario eliminado por el usuario',
  'commentDeletedByAdmin': 'Comentario eliminado por un administrador',
  'editedTag': '· EDITADO',
  'inviteCommentPrompt':
      'Consigue un código de invitación para unirte a la conversación →',
  'deleteCommentTitle': '¿Eliminar comentario?',
  'deleteCommentBodyUser':
      'Se reemplazará con “eliminado por el usuario”. Las respuestas se mantienen.',
  'deleteCommentBodyAdmin':
      'Se reemplazará con “eliminado por un administrador”. Las respuestas se mantienen.',
  'delete': 'Eliminar',
  'couldNotPost': 'No se pudo publicar: {e}',
  'couldNotSave': 'No se pudo guardar: {e}',
  'couldNotDelete': 'No se pudo eliminar: {e}',
  'globalChatLive': 'CHAT GLOBAL · EN VIVO',
  'noMessagesYet': 'Aún no hay mensajes — saluda 👋',
  'postTo': 'PUBLICAR EN',
  'generalEveryone': '🌐 General (todos)',
  'messageEveryone': 'Escribe a todos…',
  'messageAboutMatch': 'Escribe sobre este partido…',
  'send': 'Enviar',
  'inviteChatPrompt': 'Consigue un código de invitación para unirte al chat →',
  'revealMatchToRead': 'Muestra el partido para leer',
  'postingTo': 'Publicando en {match}',
  'couldNotSend': 'No se pudo enviar: {e}',
  'displayNameLabel': 'NOMBRE',
  'yourName': 'Tu nombre',
  'displayNameHint': 'Cómo apareces en el chat, comentarios y pronósticos.',
  'nameUpdated': 'Nombre actualizado',
  'favoriteTeam': 'Equipo favorito',
  'favoriteTeamHint': 'Tu bandera será tu avatar en toda la app.',
  'noFavoriteTeam': 'Sin equipo favorito',
  'favoriteTeamSet': 'Equipo favorito guardado',
  'favoriteTeamCleared': 'Equipo favorito eliminado',
  'haveInviteCode': '¿Tienes un código de invitación?',
  'redeemDesc':
      'Desbloquea comentarios, chat y pronósticos. Los códigos son de un solo uso.',
  'redeem': 'Canjear',
  'appearance': 'Apariencia',
  'themeAuto': 'Auto',
  'themeLight': 'Claro',
  'themeDark': 'Oscuro',
  'openOnLaunch': 'Al abrir',
  'openOnLaunchHint': 'Dónde se abre la app cuando vuelves.',
  'lastPage': 'Última página',
  'language': 'Idioma',
  'languageSystem': 'Predeterminado del sistema',
  'inviteCodes': 'Códigos de invitación',
  'newCode': 'Nuevo código',
  'matchAdmin': 'Administración de partidos',
  'matchAdminDesc': 'Crea, programa y edita partidos',
  'tierParticipant': 'PARTICIPANTE',
  'tierViewer': 'ESPECTADOR',
  'guestSession': 'Sesión de invitado',
  'browsingAsGuest': 'Navegando como invitado',
  'guestCardDesc':
      'Crea una cuenta para comentar, chatear y hacer pronósticos. Tus revelaciones de invitado quedan solo en este dispositivo.',
  'signInCreateAccount': 'Iniciar sesión / Crear cuenta',
  'profileUpper': 'PERFIL',
  'userNotFound': 'Usuario no encontrado.',
  'addFriend': 'Añadir amigo',
  'friendTapRemove': 'Amigo · toca para quitar',
  'addedToFriends': 'Añadido a amigos',
  'removedFromFriends': 'Eliminado de amigos',
  'supports': 'Apoya a',
  'friends': 'Amigos',
  'revealedUpper': 'REVELADO',
  'notYetRevealed': 'AÚN NO REVELADO',
  'noFriendsRevealed': 'Ningún amigo ha revelado aún.',
  'everyoneRevealed': 'Todos han revelado.',
  'noTournamentsYet': 'Aún no hay torneos',
  'noTournamentAdmin':
      'Carga los datos de ejemplo del Mundial 2026 para empezar.',
  'noTournamentViewer':
      'Vuelve pronto — un administrador debe configurar todo.',
  'seedSampleData': 'Cargar datos de ejemplo',
};

// ---------------------------------------------------------------------------
// Portuguese (European)
// ---------------------------------------------------------------------------
const Map<String, String> _pt = {
  'navMatches': 'Jogos',
  'navChat': 'Chat',
  'navProfile': 'Perfil',
  'signIn': 'Iniciar sessão',
  'signOut': 'Terminar sessão',
  'save': 'Guardar',
  'cancel': 'Cancelar',
  'createAccount': 'Criar conta',
  'email': 'Email',
  'password': 'Palavra-passe',
  'taglineSpoilerFree': 'MUNDIAL 2026 · SEM SPOILERS',
  'strengthScheduleTitle': 'Calendário sem spoilers',
  'strengthScheduleDesc':
      'Os resultados, comentários e palpites ficam ocultos até decidires revelá-los.',
  'strengthFriendsTitle': 'Vê que amigos já viram',
  'strengthFriendsDesc': 'Sabe quem já viu um jogo — sem revelar o resultado.',
  'browseMatches': 'Ver jogos',
  'signInOrCreate': 'Inicia sessão ou cria conta',
  'browseReadOnly':
      'A navegação é só de leitura. Um código de convite desbloqueia o chat e os palpites.',
  'continueWithGoogle': 'Continuar com o Google',
  'orLabel': 'OU',
  'alreadyHaveAccount': 'Já tens conta? ',
  'newHere': 'Primeira vez aqui? ',
  'createAnAccount': 'Criar uma conta',
  'searchHint': 'Procura equipas ou fase…',
  'filterAll': 'Todos',
  'filterUpcoming': 'Próximos',
  'filterLive': 'Ao vivo',
  'filterFinished': 'Terminados',
  'filterArchived': 'Arquivados',
  'shownCount': '{n} VISÍVEIS',
  'noMatchesSearch': 'Nenhum jogo corresponde à tua procura.',
  'couldNotLoadMatches': 'Não foi possível carregar os jogos.',
  'startsIn': 'Começa em {time}',
  'statusUpcoming': 'POR JOGAR',
  'statusLive': '● AO VIVO',
  'statusFullTime': 'FIM DE JOGO',
  'archivedUpper': 'ARQUIVADO',
  'hiddenUpper': 'OCULTO',
  'archiveUpper': 'ARQUIVAR',
  'restoreUpper': 'RESTAURAR',
  'editUpper': 'EDITAR',
  'matchNotFound': 'Jogo não encontrado.',
  'yourLocalTime': 'A TUA HORA LOCAL ({tz})',
  'reveal': 'Revelar',
  'hideUpper': 'OCULTAR',
  'predictions': 'Palpites',
  'comments': 'Comentários',
  'goalsCount': '{n} GOLOS',
  'revealGoals': 'Revelar golos',
  'goalsTapScorers': 'GOLOS · TOCA PARA VER MARCADORES',
  'scorersTapHide': 'MARCADORES · TOCA PARA OCULTAR',
  'friendSingular': 'amigo',
  'friendPlural': 'amigos',
  'viewMatchesUpper': 'JOGOS',
  'scheduleResultsUpper': 'CALENDÁRIO E RESULTADOS',
  'played': 'Jogados',
  'teamMatchesCount': '{n} JOGOS',
  'noTeamMatches': 'Ainda não há jogos de {team}.',
  'homeShort': 'CASA',
  'awayShort': 'FORA',
  'vsOpponent': 'vs {team}',
  'yourPrediction': 'O teu palpite',
  'updateYourPrediction': 'Atualiza o teu palpite',
  'predict': 'Palpitar',
  'update': 'Atualizar',
  'cancelUpper': 'CANCELAR',
  'editUpperShort': 'EDITAR',
  'deleteUpper': 'ELIMINAR',
  'yourPredictionIsIn': 'O teu palpite está registado',
  'everyonesPredictions': 'PALPITES DE TODOS',
  'noPredictionsYet': 'Ainda não há palpites.',
  'enterBothScores': 'Indica os dois resultados',
  'predictionSubmitted': 'Palpite enviado ✅',
  'predictionUpdated': 'Palpite atualizado ✅',
  'predictionRemoved': 'Palpite removido',
  'couldNotSubmit': 'Não foi possível enviar: {e}',
  'couldNotRemove': 'Não foi possível remover: {e}',
  'invitePredictionPrompt':
      'Obtém um código de convite para adicionar o teu palpite →',
  'predictionsHidden': '{n} PALPITES OCULTOS',
  'revealPredictions': 'Revelar palpites',
  'predictionsLocked': 'Palpites bloqueados',
  'predictionsLockedLiveDesc':
      'O jogo já começou — os palpites estão fechados.',
  'predictionsLockedOverDesc':
      'Este jogo terminou — os palpites estão fechados.',
  'revealComments': 'Revelar comentários',
  'commentsHidden': '{n} COMENTÁRIOS OCULTOS',
  'noCommentsYet': 'Ainda não há comentários — sê o primeiro.',
  'addComment': 'Adiciona um comentário…',
  'replyHint': 'Responder…',
  'replyUpper': '↳ RESPONDER',
  'replyButton': 'Responder',
  'postButton': 'Publicar',
  'editComment': 'Edita o comentário…',
  'commentDeletedByUser': 'Comentário eliminado pelo utilizador',
  'commentDeletedByAdmin': 'Comentário eliminado por um administrador',
  'editedTag': '· EDITADO',
  'inviteCommentPrompt': 'Obtém um código de convite para entrar na conversa →',
  'deleteCommentTitle': 'Eliminar comentário?',
  'deleteCommentBodyUser':
      'Será substituído por “eliminado pelo utilizador”. As respostas permanecem.',
  'deleteCommentBodyAdmin':
      'Será substituído por “eliminado por um administrador”. As respostas permanecem.',
  'delete': 'Eliminar',
  'couldNotPost': 'Não foi possível publicar: {e}',
  'couldNotSave': 'Não foi possível guardar: {e}',
  'couldNotDelete': 'Não foi possível eliminar: {e}',
  'globalChatLive': 'CHAT GLOBAL · AO VIVO',
  'noMessagesYet': 'Ainda não há mensagens — diz olá 👋',
  'postTo': 'PUBLICAR EM',
  'generalEveryone': '🌐 Geral (todos)',
  'messageEveryone': 'Mensagem para todos…',
  'messageAboutMatch': 'Mensagem sobre este jogo…',
  'send': 'Enviar',
  'inviteChatPrompt': 'Obtém um código de convite para entrar no chat →',
  'revealMatchToRead': 'Revela o jogo para ler',
  'postingTo': 'A publicar em {match}',
  'couldNotSend': 'Não foi possível enviar: {e}',
  'displayNameLabel': 'NOME',
  'yourName': 'O teu nome',
  'displayNameHint': 'Como apareces no chat, comentários e palpites.',
  'nameUpdated': 'Nome atualizado',
  'favoriteTeam': 'Equipa favorita',
  'favoriteTeamHint': 'A tua bandeira passa a ser o teu avatar na app.',
  'noFavoriteTeam': 'Sem equipa favorita',
  'favoriteTeamSet': 'Equipa favorita definida',
  'favoriteTeamCleared': 'Equipa favorita removida',
  'haveInviteCode': 'Tens um código de convite?',
  'redeemDesc':
      'Desbloqueia comentários, chat e palpites. Os códigos são de uso único.',
  'redeem': 'Resgatar',
  'appearance': 'Aparência',
  'themeAuto': 'Auto',
  'themeLight': 'Claro',
  'themeDark': 'Escuro',
  'openOnLaunch': 'Ao abrir',
  'openOnLaunchHint': 'Onde a app abre quando voltas.',
  'lastPage': 'Última página',
  'language': 'Idioma',
  'languageSystem': 'Predefinição do sistema',
  'inviteCodes': 'Códigos de convite',
  'newCode': 'Novo código',
  'matchAdmin': 'Gestão de jogos',
  'matchAdminDesc': 'Cria, agenda e edita jogos',
  'tierParticipant': 'PARTICIPANTE',
  'tierViewer': 'ESPECTADOR',
  'guestSession': 'Sessão de convidado',
  'browsingAsGuest': 'A navegar como convidado',
  'guestCardDesc':
      'Cria uma conta para comentar, conversar e fazer palpites. As tuas revelações de convidado ficam só neste dispositivo.',
  'signInCreateAccount': 'Iniciar sessão / Criar conta',
  'profileUpper': 'PERFIL',
  'userNotFound': 'Utilizador não encontrado.',
  'addFriend': 'Adicionar amigo',
  'friendTapRemove': 'Amigo · toca para remover',
  'addedToFriends': 'Adicionado aos amigos',
  'removedFromFriends': 'Removido dos amigos',
  'supports': 'Apoia',
  'friends': 'Amigos',
  'revealedUpper': 'REVELADO',
  'notYetRevealed': 'AINDA NÃO REVELADO',
  'noFriendsRevealed': 'Nenhum amigo revelou ainda.',
  'everyoneRevealed': 'Todos revelaram.',
  'noTournamentsYet': 'Ainda não há torneios',
  'noTournamentAdmin':
      'Carrega os dados de exemplo do Mundial 2026 para começar.',
  'noTournamentViewer':
      'Volta em breve — um administrador precisa de configurar tudo.',
  'seedSampleData': 'Carregar dados de exemplo',
};

// ---------------------------------------------------------------------------
// Portuguese (Brazilian) — overrides where it differs from European Portuguese.
// ---------------------------------------------------------------------------
const Map<String, String> _ptBR = {
  'navMatches': 'Partidas',
  'signIn': 'Entrar',
  'signOut': 'Sair',
  'save': 'Salvar',
  'password': 'Senha',
  'taglineSpoilerFree': 'COPA DO MUNDO 2026 · SEM SPOILERS',
  'strengthScheduleTitle': 'Agenda sem spoilers',
  'strengthScheduleDesc':
      'Os placares, comentários e palpites ficam ocultos até você decidir revelá-los.',
  'strengthFriendsTitle': 'Veja quais amigos já assistiram',
  'strengthFriendsDesc':
      'Saiba quem já viu uma partida — sem revelar o resultado.',
  'browseMatches': 'Ver partidas',
  'signInOrCreate': 'Entre ou crie uma conta',
  'browseReadOnly':
      'A navegação é somente leitura. Um código de convite libera o chat e os palpites.',
  'alreadyHaveAccount': 'Já tem uma conta? ',
  'searchHint': 'Busque times ou fase…',
  'filterFinished': 'Encerrados',
  'noMatchesSearch': 'Nenhuma partida corresponde à sua busca.',
  'couldNotLoadMatches': 'Não foi possível carregar as partidas.',
  'startsIn': 'Começa em {time}',
  'statusUpcoming': 'EM BREVE',
  'matchNotFound': 'Partida não encontrada.',
  'yourLocalTime': 'SEU HORÁRIO LOCAL ({tz})',
  'goalsCount': '{n} GOLS',
  'revealGoals': 'Revelar gols',
  'goalsTapScorers': 'GOLS · TOQUE PARA VER QUEM MARCOU',
  'scorersTapHide': 'ARTILHEIROS · TOQUE PARA OCULTAR',
  'viewMatchesUpper': 'PARTIDAS',
  'played': 'Jogadas',
  'teamMatchesCount': '{n} PARTIDAS',
  'noTeamMatches': 'Ainda não há partidas de {team}.',
  'yourPrediction': 'Seu palpite',
  'updateYourPrediction': 'Atualize seu palpite',
  'yourPredictionIsIn': 'Seu palpite foi registrado',
  'enterBothScores': 'Informe os dois placares',
  'invitePredictionPrompt':
      'Consiga um código de convite para adicionar seu palpite →',
  'predictionsLockedLiveDesc':
      'A partida já começou — os palpites estão fechados.',
  'predictionsLockedOverDesc':
      'Esta partida terminou — os palpites estão fechados.',
  'noCommentsYet': 'Ainda não há comentários — seja o primeiro.',
  'addComment': 'Adicione um comentário…',
  'editComment': 'Edite o comentário…',
  'commentDeletedByUser': 'Comentário excluído pelo usuário',
  'commentDeletedByAdmin': 'Comentário excluído por um administrador',
  'inviteCommentPrompt':
      'Consiga um código de convite para entrar na conversa →',
  'deleteCommentTitle': 'Excluir comentário?',
  'deleteCommentBodyUser':
      'Será substituído por “excluído pelo usuário”. As respostas permanecem.',
  'deleteCommentBodyAdmin':
      'Será substituído por “excluído por um administrador”. As respostas permanecem.',
  'delete': 'Excluir',
  'deleteUpper': 'EXCLUIR',
  'couldNotSave': 'Não foi possível salvar: {e}',
  'couldNotDelete': 'Não foi possível excluir: {e}',
  'noMessagesYet': 'Ainda não há mensagens — diga oi 👋',
  'messageEveryone': 'Mensagem para todos…',
  'messageAboutMatch': 'Mensagem sobre esta partida…',
  'revealMatchToRead': 'Revele a partida para ler',
  'postingTo': 'Publicando em {match}',
  'displayNameHint': 'Como você aparece no chat, comentários e palpites.',
  'favoriteTeam': 'Time favorito',
  'favoriteTeamHint': 'Sua bandeira vira seu avatar no app.',
  'noFavoriteTeam': 'Sem time favorito',
  'favoriteTeamSet': 'Time favorito definido',
  'favoriteTeamCleared': 'Time favorito removido',
  'haveInviteCode': 'Tem um código de convite?',
  'redeemDesc':
      'Libere comentários, chat e palpites. Os códigos são de uso único.',
  'matchAdmin': 'Administração de partidas',
  'matchAdminDesc': 'Crie, agende e edite partidas',
  'openOnLaunchHint': 'Onde o app abre quando você volta.',
  'tierViewer': 'VISITANTE',
  'browsingAsGuest': 'Navegando como convidado',
  'guestCardDesc':
      'Crie uma conta para comentar, conversar e fazer palpites. Suas revelações de convidado ficam só neste dispositivo.',
  'signInCreateAccount': 'Entrar / Criar conta',
  'userNotFound': 'Usuário não encontrado.',
  'supports': 'Torce por',
  'noTournamentAdmin':
      'Carregue os dados de exemplo da Copa do Mundo 2026 para começar.',
  'noTournamentViewer':
      'Volte em breve — um administrador precisa configurar tudo.',
  'seedSampleData': 'Carregar dados de exemplo',
};
