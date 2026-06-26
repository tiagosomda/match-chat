do one task at a time, but feel free to group similar tasks together tho.
don't let changes pile up tho, make sure to git commit as you go.

# Improvements

- persist across sessions : match filter and search, last opened page (able to set it via profile. As in to open in the last page we had open or in the matches tab)
- add match location (like stadium and city) … display this info in the matches screen and in the match detail screen 
- in the match detail screen, the description info at the header is not wide enough for the info we may put there. So instead let’s put that in the container where we have the two teams. Perhaps at the top of that container?
- some countries don’t have flags. Try to figure out which ones they are and if you can fix it.
- prediction: after a game is over we hide the prediction container that allows us to make a prediction. Instead, let’s just block it with a message saying that it is locked or the match is over.
- match prediction ui; add little arrows above and below the input field so we can just press that instead of using an input field (make sure to do state and data validation .. like negative numbers shouldn’t be allowed only 0 and higher)
- when clicking on a country, it would be nice to get a history/summary of their previous and upcoming matches
- prediction score leaderboard with different tabs (friends, global rank top ones and people near your rank) with a search filter across both tabs and for scoring Skill‑weighted 
• Exact score: 5 points
• Correct goal difference: 3 points
• Correct result: 1 point


Backend Pooler
- verify if script logic is solid and without issues. I don’t want a bug that will cause me to hit my rate limit for the day. Be extra careful and defensive.
- and right now the pooling is a bit slow, but that was thinking of the free tier, but this API doesn’t have a free tier for the World Cup scores, so I paid a subscription and now I have 7000 requests per day
