
# Remind my mind



This bot allows you to store notes linked to the telegram chat where the bot was added

If you have any comment about this bot/code/idea feel free to write me in telegram `@Sabaverus`
  

At the moment, the bot is in development and only the main functionality is available:

- Adding record step by step
- Change record fields
- Delete record
  

To run this bot in development stage

- Install Elixir https://elixir-lang.org/install.html
- Clone this repo
- Go to project_folder/config and rename dev.copy.exs to dev.exs
- Fill `dev.exs` with database credentials and telegram token of ur bot
- Go to project root directory and run
-  -  `mix ecto.setup`
-  -  `mix ecto.migrate`
-  -  `iex -S mix`

Roadmap:

 - [ ] Fill with tests
 - [ ] Bot-Script messages cleanup
 - [ ] "Closed" records, where need request accept to show record from author or chat-admin
 - [ ] Self-deleting messages after show
 - [ ] Fill with tests again
 - [ ] Add MakeFile
 - [ ] Prepare to run in production
