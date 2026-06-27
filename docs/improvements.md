work one task at a time, but feel free to group them together as needed.
However, don't let the work pile up, test and git commit often.
Add unit tests whenever you think is appropriated, remove other tests if you think it is best

----here are the tasks

- there are links like in the prediction tab that should be taking us to the profile page, they are not working / or just not clickable
- the links should say something more like, “interacting here is invite only redeem a code from a friend here” (I don’t think I phrased it well, so please change it up to be friendly and concise)
- in the profile page at the bottom let’s put an about section and let’s say this was >"developed by Tiago and put a link to my url: (https://links.tiago.dev) and it will be free for the entire duration of the World Cup and if anyone wants to buy me some coffee or help with the costs of running the app to then tip me at https://ko-fi.com/tiagodev"< … again something like that but not word for word. we want to convey these things, but in a friendly tone. Perhaps we can have a dedicated about page. In the profile we can keep it simple, made this for fun! Keeping it free during the World Cup! Enjoy! Know more about Tiago? And one more thing tapping the match chat name/logo at the header should take us to the about page.
- the list of matches that have finished should go from the most recent to the oldest. or in the case of upcoming... from the nearest to the furthest
- pulling down in the profile page might need to hit a refresh (to see things like if anyone has claimed the invite code)
- input validation (special chars, text too long, injection, etc)
- when you first login with the app or press to browse the games - the app stays in a loading state for a very long time. If I refresh the page, it almost loads instantly. Can you try to find out what might be happening and fix it?
- when I switch to the rank tab, it takes a looong time to calculate the leaderboard. If I switch to another tab and I then come back, it again takes a while to load. perhaps we can have the backend poller take care of that as games are finished?
- at the top header where we have the profile icon, let’s put the user name there as well (clicking it should go to the profile page as well) - and then remove the bottom button for the profile tab
- and then make the ranking tab be the last (matches, chat stream (I forget the actual name tho) and then ranks)
- we need some more spacing at the bottom. Right now the iPhone (and maybe android) bottom bar/ui covers the navigation bar text)
- in the matches screen let’s make the all filter be the second to last and then the last one just the archived icon (no archived text). Actually here is something better. Don’t include the archived button there at all. At the end of the list of matches we can have a little button/toggle to show/hide archived matches.
- the games that show in live should have a time padding before it starts and after it finishes. I think this can be handled in the uI itself and show their statuses as “live soon” and “just finished”
- I noticed if I change my user name, my chat messages and thread messages don’t have my newly updated name. I think that is because of how we store the messages so we don’t need to retrieve the user name for each user name? So I think perhaps we need to put a safety guard to only allow changing your own name every 3 days. So when changing your name, we should have a pop up to have the user confirm and in it we say that their message names in chat and thread won’t get updated right away. I guess in the backend we can detect that the name was changed, perhaps we keep a flag there and a background process can go and update the message names slowly over time?
- in the matches page, if the game is today, we should have a different color than the accent one and say today instead of upcoming and then same for tomorrow, let’s have yet another color and say tomorrow
- in the matches page details page where it shows your prediction… it just shows the numbers but doesn’t say for which team each prediction is. I think we can keep the prediction UI similar to the edit/set prediction UI.
- while in the matches details, I think that if we swipe left/right at the top part of the screen (like where it says the score, we should load the next/previous game (next/prev time wise) - make sure to handle the case of games having the same start time. Whatever rule you choose just be consistent.
- in the matches screen, we need a way to show your prediction. In the app profile settings tho, we should have an option for people who don’t care about predictions and then can toggle off the predictions. Same thing for chats and comments. Let’s have such a setting as well
