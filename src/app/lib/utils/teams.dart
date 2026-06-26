/// A national team with its flag emoji. Used for the favorite-team picker and
/// admin match creation. The list is generic (not hard-coded to one
/// tournament) but covers likely World Cup 2026 participants.
class Team {
  const Team(this.name, this.flag);
  final String name;
  final String flag;
}

class Teams {
  Teams._();

  static const List<Team> all = <Team>[
    Team('Argentina', '🇦🇷'),
    Team('Australia', '🇦🇺'),
    Team('Austria', '🇦🇹'),
    Team('Belgium', '🇧🇪'),
    Team('Brazil', '🇧🇷'),
    Team('Cameroon', '🇨🇲'),
    Team('Canada', '🇨🇦'),
    Team('Colombia', '🇨🇴'),
    Team('Costa Rica', '🇨🇷'),
    Team('Croatia', '🇭🇷'),
    Team('Denmark', '🇩🇰'),
    Team('Ecuador', '🇪🇨'),
    Team('Egypt', '🇪🇬'),
    Team('England', '🏴󠁧󠁢󠁥󠁮󠁧󠁿'),
    Team('France', '🇫🇷'),
    Team('Germany', '🇩🇪'),
    Team('Ghana', '🇬🇭'),
    Team('Iran', '🇮🇷'),
    Team('Italy', '🇮🇹'),
    Team('Ivory Coast', '🇨🇮'),
    Team('Japan', '🇯🇵'),
    Team('Mexico', '🇲🇽'),
    Team('Morocco', '🇲🇦'),
    Team('Netherlands', '🇳🇱'),
    Team('Nigeria', '🇳🇬'),
    Team('Norway', '🇳🇴'),
    Team('Poland', '🇵🇱'),
    Team('Portugal', '🇵🇹'),
    Team('Qatar', '🇶🇦'),
    Team('Saudi Arabia', '🇸🇦'),
    Team('Senegal', '🇸🇳'),
    Team('Serbia', '🇷🇸'),
    Team('South Korea', '🇰🇷'),
    Team('Spain', '🇪🇸'),
    Team('Sweden', '🇸🇪'),
    Team('Switzerland', '🇨🇭'),
    Team('Tunisia', '🇹🇳'),
    Team('Uruguay', '🇺🇾'),
    Team('USA', '🇺🇸'),
    Team('Wales', '🏴󠁧󠁢󠁷󠁬󠁳󠁿'),
  ];

  static const String unknownFlag = '🏳️';

  static String flagFor(String? name) {
    if (name == null) return unknownFlag;
    for (final t in all) {
      if (t.name == name) return t.flag;
    }
    return unknownFlag;
  }
}
