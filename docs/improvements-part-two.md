- [x] time until match starts
- [x] localize app in Portuguese (portugal and brazilian), Spanish, English. Auto detect language based on device configuration and let user change it in their profile page
  - NOTE: participant-facing screens are fully localized (en, es, pt-PT,
    pt-BR). Device locale is auto-detected; a picker in Profile > Language
    overrides it. Admin-only screens remain in English.
- [x] app strenghts : change wording on main page to indicate the follow : spoiler-free schedule, see which of your friends has seen a match
- [x] home page, instead of opening up with a login page, have a button to see the match list info (no login required) - sort of like doing a login, but without a friend code, and then below it a button for sign in/up
  - NOTE: implemented via Firebase Anonymous auth. The Anonymous sign-in
    provider must be enabled in the Firebase console (Authentication > Sign-in
    method) for "Browse matches" to work.
