/// A national team with its flag emoji. Used for the favorite-team picker and
/// admin match creation.
///
/// Flags are derived from each country's ISO 3166-1 alpha-2 code (two regional
/// indicator symbols) rather than hand-typed emoji, so the list stays correct
/// and is easy to extend. A handful of entries (the UK home nations) use the
/// special subdivision flag sequences instead.
class Team {
  const Team(this.name, this.flag);
  final String name;
  final String flag;
}

class Teams {
  Teams._();

  /// Canonical team name -> ISO 3166-1 alpha-2 code.
  static const Map<String, String> _iso = <String, String>{
    // CONMEBOL
    'Argentina': 'AR',
    'Bolivia': 'BO',
    'Brazil': 'BR',
    'Chile': 'CL',
    'Colombia': 'CO',
    'Ecuador': 'EC',
    'Paraguay': 'PY',
    'Peru': 'PE',
    'Uruguay': 'UY',
    'Venezuela': 'VE',
    // CONCACAF
    'Canada': 'CA',
    'Costa Rica': 'CR',
    'Cuba': 'CU',
    'Curaçao': 'CW',
    'Dominican Republic': 'DO',
    'El Salvador': 'SV',
    'Guatemala': 'GT',
    'Haiti': 'HT',
    'Honduras': 'HN',
    'Jamaica': 'JM',
    'Mexico': 'MX',
    'Nicaragua': 'NI',
    'Panama': 'PA',
    'Suriname': 'SR',
    'Trinidad and Tobago': 'TT',
    'USA': 'US',
    // UEFA
    'Albania': 'AL',
    'Armenia': 'AM',
    'Austria': 'AT',
    'Azerbaijan': 'AZ',
    'Belarus': 'BY',
    'Belgium': 'BE',
    'Bosnia and Herzegovina': 'BA',
    'Bulgaria': 'BG',
    'Croatia': 'HR',
    'Cyprus': 'CY',
    'Czech Republic': 'CZ',
    'Denmark': 'DK',
    'Estonia': 'EE',
    'Finland': 'FI',
    'France': 'FR',
    'Georgia': 'GE',
    'Germany': 'DE',
    'Greece': 'GR',
    'Hungary': 'HU',
    'Iceland': 'IS',
    'Israel': 'IL',
    'Italy': 'IT',
    'Kazakhstan': 'KZ',
    'Kosovo': 'XK',
    'Latvia': 'LV',
    'Lithuania': 'LT',
    'Luxembourg': 'LU',
    'Malta': 'MT',
    'Moldova': 'MD',
    'Montenegro': 'ME',
    'Netherlands': 'NL',
    'North Macedonia': 'MK',
    'Norway': 'NO',
    'Poland': 'PL',
    'Portugal': 'PT',
    'Republic of Ireland': 'IE',
    'Romania': 'RO',
    'Russia': 'RU',
    'Serbia': 'RS',
    'Slovakia': 'SK',
    'Slovenia': 'SI',
    'Spain': 'ES',
    'Sweden': 'SE',
    'Switzerland': 'CH',
    'Turkey': 'TR',
    'Ukraine': 'UA',
    // CAF
    'Algeria': 'DZ',
    'Angola': 'AO',
    'Benin': 'BJ',
    'Botswana': 'BW',
    'Burkina Faso': 'BF',
    'Burundi': 'BI',
    'Cameroon': 'CM',
    'Cape Verde': 'CV',
    'Comoros': 'KM',
    'Congo': 'CG',
    'DR Congo': 'CD',
    'Egypt': 'EG',
    'Equatorial Guinea': 'GQ',
    'Ethiopia': 'ET',
    'Gabon': 'GA',
    'Gambia': 'GM',
    'Ghana': 'GH',
    'Guinea': 'GN',
    'Guinea-Bissau': 'GW',
    'Ivory Coast': 'CI',
    'Kenya': 'KE',
    'Libya': 'LY',
    'Madagascar': 'MG',
    'Malawi': 'MW',
    'Mali': 'ML',
    'Mauritania': 'MR',
    'Morocco': 'MA',
    'Mozambique': 'MZ',
    'Namibia': 'NA',
    'Nigeria': 'NG',
    'Rwanda': 'RW',
    'Senegal': 'SN',
    'Sierra Leone': 'SL',
    'South Africa': 'ZA',
    'Sudan': 'SD',
    'Tanzania': 'TZ',
    'Togo': 'TG',
    'Tunisia': 'TN',
    'Uganda': 'UG',
    'Zambia': 'ZM',
    'Zimbabwe': 'ZW',
    // AFC
    'Australia': 'AU',
    'Bahrain': 'BH',
    'China': 'CN',
    'India': 'IN',
    'Indonesia': 'ID',
    'Iran': 'IR',
    'Iraq': 'IQ',
    'Japan': 'JP',
    'Jordan': 'JO',
    'Kuwait': 'KW',
    'Kyrgyzstan': 'KG',
    'Lebanon': 'LB',
    'Malaysia': 'MY',
    'Oman': 'OM',
    'Palestine': 'PS',
    'Philippines': 'PH',
    'Qatar': 'QA',
    'Saudi Arabia': 'SA',
    'South Korea': 'KR',
    'North Korea': 'KP',
    'Syria': 'SY',
    'Tajikistan': 'TJ',
    'Thailand': 'TH',
    'Turkmenistan': 'TM',
    'United Arab Emirates': 'AE',
    'Uzbekistan': 'UZ',
    'Vietnam': 'VN',
    'Yemen': 'YE',
    // OFC
    'Fiji': 'FJ',
    'New Caledonia': 'NC',
    'New Zealand': 'NZ',
    'Papua New Guinea': 'PG',
    'Solomon Islands': 'SB',
    'Tahiti': 'PF',
    'Vanuatu': 'VU',
  };

  /// Names whose flag isn't a plain ISO2 pair (UK home nations use the special
  /// subdivision flag emoji sequences).
  static const Map<String, String> _special = <String, String>{
    'England': '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
    'Scotland': '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
    'Wales': '🏴󠁧󠁢󠁷󠁬󠁳󠁿',
    'Northern Ireland': '🇬🇧',
  };

  /// Alternate spellings (e.g. from the results API) -> the canonical name used
  /// in [_iso] / [_special]. Keep this in sync with the poller's teams.py.
  static const Map<String, String> _aliases = <String, String>{
    'United States': 'USA',
    'United States of America': 'USA',
    'Korea Republic': 'South Korea',
    'Korea DPR': 'North Korea',
    'Côte d\'Ivoire': 'Ivory Coast',
    'Cote d\'Ivoire': 'Ivory Coast',
    'IR Iran': 'Iran',
    'Czechia': 'Czech Republic',
    'Türkiye': 'Turkey',
    'Turkiye': 'Turkey',
    'Cabo Verde': 'Cape Verde',
    'Cape Verde Islands': 'Cape Verde',
    'Congo DR': 'DR Congo',
    'Congo-Kinshasa': 'DR Congo',
    'DR Congo (Kinshasa)': 'DR Congo',
    'Macedonia': 'North Macedonia',
    'Bosnia': 'Bosnia and Herzegovina',
    'UAE': 'United Arab Emirates',
    'Ireland': 'Republic of Ireland',
    'Trinidad And Tobago': 'Trinidad and Tobago',
    'Curacao': 'Curaçao',
    'China PR': 'China',
  };

  static const String unknownFlag = '🏳️';

  /// All pickable teams, sorted alphabetically, with their resolved flags.
  static final List<Team> all = _buildAll();

  static List<Team> _buildAll() {
    final names = <String>{..._iso.keys, ..._special.keys}.toList()..sort();
    return [for (final name in names) Team(name, flagFor(name))];
  }

  /// Resolves a country name (accepting common aliases) to its flag emoji,
  /// falling back to a neutral white flag for unknown teams.
  static String flagFor(String? name) {
    if (name == null) return unknownFlag;
    final canonical = _canonical(name.trim());
    if (canonical.isEmpty) return unknownFlag;
    final special = _special[canonical];
    if (special != null) return special;
    final iso = _iso[canonical];
    if (iso != null) return _flagFromIso(iso);
    return unknownFlag;
  }

  static String _canonical(String name) => _aliases[name] ?? name;

  /// Converts a two-letter ISO code into its flag emoji by mapping each letter
  /// to its regional indicator symbol (A=0x1F1E6).
  static String _flagFromIso(String iso) {
    final upper = iso.toUpperCase();
    const base = 0x1F1E6;
    const aCode = 0x41; // 'A'
    return String.fromCharCodes(<int>[
      base + (upper.codeUnitAt(0) - aCode),
      base + (upper.codeUnitAt(1) - aCode),
    ]);
  }
}
