// Flag-resolution coverage tests (improvements.md #4: "some countries don't
// have flags"). These lock in that every pickable team resolves to a real flag
// and that the team names the results API (API-Football) actually emits — plus
// every World Cup 2026 participant — never fall back to the neutral flag.
import 'package:flutter_test/flutter_test.dart';
import 'package:match_chat/utils/teams.dart';

void main() {
  test('every pickable team resolves to a real flag', () {
    final broken = Teams.all
        .where((t) => t.flag.isEmpty || t.flag == Teams.unknownFlag)
        .map((t) => t.name)
        .toList();
    expect(broken, isEmpty, reason: 'These picker teams have no flag: $broken');
  });

  test('World Cup 2026 participants and API name variants resolve to a flag', () {
    // Real-world names that can appear in match data, including the exact
    // spellings API-Football uses for the trickier nations.
    const names = <String>[
      // Hosts + CONMEBOL
      'USA', 'United States', 'Canada', 'Mexico',
      'Argentina', 'Brazil', 'Uruguay', 'Colombia', 'Ecuador', 'Paraguay',
      'Bolivia', 'Peru', 'Chile', 'Venezuela',
      // UEFA
      'England', 'Scotland', 'Wales', 'Northern Ireland',
      'France', 'Spain', 'Portugal', 'Germany', 'Netherlands', 'Belgium',
      'Croatia', 'Italy', 'Switzerland', 'Austria', 'Denmark', 'Poland',
      'Serbia', 'Norway', 'Turkey', 'Türkiye', 'Turkiye', 'Czech Republic',
      'Czechia', 'Ukraine', 'Sweden', 'Hungary', 'Greece', 'Romania',
      'Slovakia', 'Slovenia', 'Albania', 'Bosnia and Herzegovina', 'Bosnia',
      'North Macedonia', 'Macedonia', 'Republic of Ireland', 'Ireland',
      'Iceland', 'Finland', 'Montenegro', 'Kosovo', 'Georgia',
      // CAF
      'Morocco', 'Senegal', 'Tunisia', 'Algeria', 'Egypt', 'Ghana',
      'Ivory Coast', "Côte d'Ivoire", "Cote d'Ivoire", 'Cameroon', 'Nigeria',
      'Mali', 'South Africa', 'Cape Verde', 'Cabo Verde', 'Cape Verde Islands',
      'DR Congo', 'Congo DR', 'Congo-Kinshasa', 'Burkina Faso',
      'Equatorial Guinea', 'Gabon', 'Angola', 'Zambia',
      // AFC
      'Japan', 'South Korea', 'Korea Republic', 'Iran', 'IR Iran', 'Australia',
      'Saudi Arabia', 'Qatar', 'Uzbekistan', 'Jordan', 'Iraq',
      'United Arab Emirates', 'UAE', 'North Korea', 'Korea DPR', 'China',
      'China PR', 'India', 'Indonesia', 'Bahrain', 'Oman', 'Vietnam',
      'Thailand', 'Lebanon', 'Syria', 'Palestine', 'Kuwait', 'Kyrgyzstan',
      'Tajikistan',
      // OFC
      'New Zealand', 'New Caledonia', 'Fiji', 'Tahiti', 'Solomon Islands',
      'Vanuatu', 'Papua New Guinea',
      // CONCACAF
      'Panama', 'Costa Rica', 'Honduras', 'Jamaica', 'Curaçao', 'Curacao',
      'Haiti', 'Trinidad and Tobago', 'Trinidad And Tobago', 'El Salvador',
      'Guatemala', 'Suriname', 'Nicaragua',
    ];

    final unresolved = names
        .where((n) => Teams.flagFor(n) == Teams.unknownFlag)
        .toList();
    expect(
      unresolved,
      isEmpty,
      reason: 'These names fall back to the neutral flag: $unresolved',
    );
  });
}
