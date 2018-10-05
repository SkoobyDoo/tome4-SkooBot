Basic bot designed to automate some of the tedium of starting a new character.
This bot will rest, explore, and use a very basic algorithm for engaging in combat.
You will need to configure your hotbar specifically for the use of this bot,
as it uses the positioning of skills on your hotbar according to the following rules:
* Main combat rotation in hotkeys 1-0 (ten slots). These will be used left to right, always using the leftmost one that has a legal target.
* Sustain talents in A1-A0 (ten slots) will always be activated when available. You may need to resize your bar to get access to these slots.
* pre-emptive damage prevention or instant heals should be placed in S1/S2, these are used when large damage spikes are detected to the player.
* Recovery healing spells should be placed in S3/S4, these are used when the player is missing 25% life or more.

Hotkey defaults are as follows and can be configured in the options screen:
* Alt + F1 - Toggle bot
* Shift + F1 - Disable bot (I recommend holding this when the bot is active as its difficult to press it at a time when the bot will listen)
* Alt + F2 - Single Step bot - This has the bot perform a single action without fully engaging autopilot.
  Useful when you want to supervise the bot's behavior. Currently a bit buggy and may not run more than 25 times in a row.
* Alt + F3 - Query bot - This prompts the bot to declare the next action it would take, but should not perform any action.
This will probably not even get close to beating the game for you, and will frequently run into situations that it will not be able to act in.

Changes in 0.0.2:
* Bot stops when it levels up
* Bot stops when detecting most major debuffs (Stun, daze, sleep, blind, confuse)
* Less complaining when underwater as undead
* Fixed a few sources of unnecessary bot stops due to logic errors
* Fixed some logic surrounding runOnce
* Fixed an error where Query would actually take an action

Upcoming Features (in no particular order):
* Separate UI for configuring combat rotation to let you keep your bar the way you want
* Companion addons and an integration with this bot to auto-spend levelup points and optimize equipment so you don't have to
* Ability to make bot stop based on enemies spotted (# of enemies, highest tier of enemy spotted e.g. pause on rare/unique/boss, # of levels above you, etc)
* Recognize area damage and avoid standing in it
* Make items a valid choice for combat rotation. Currently items on the hotbar are ignored.
* Pause bot when a dialogue is shown
* UI to enable or disable any of the various features I've added so you can customize the way the bot performs.
* Anything else I think of.
* BUG FIXES!