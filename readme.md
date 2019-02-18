Basic bot designed to automate some of the tedium of starting a new character.
This bot will rest, explore, and use a very basic algorithm for engaging in combat.
You will need to configure the bot's talent usage from within the game (Shift + F2 -> Option a)
* Combat abilities will be used in DESCENDING priority order
* Sustain talents will be kept active at all times
* Damage prevention talents are used when "large" damage spikes are detected to the player.
* Recovery talents are used when the player is missing 25% life or more. (Threshold configurable from menu under [Skoobot] tab)

Hotkey defaults are as follows and can be configured in the options screen:
* Alt + F1 - Toggle bot
* Shift + F1 - Disable bot (I recommend holding this when the bot is active as its difficult to press it at a time when the bot will listen)
* Alt + F2 - Single Step bot - This has the bot perform a single action without fully engaging autopilot. Useful when you want to supervise the bot's behavior. Currently a bit buggy and may not run more than 25 times in a row.
* Shift + F2 - SkooBot Menu - Currently the only option is to configure talent usage as well as configure which stop conditions are active
* Alt + F3 - Query bot - This prompts the bot to declare the next action it would take, but should not perform any action.
This will probably not even get close to beating the game for you, and will frequently run into situations that it will not be able to act in.

Changes in 0.0.9
* Fix talent configuration bug when a talent (usually inscription) is no longer available.

Changes in 0.0.7
* Filtered talent selection dialog to not include passive or hidden talents and also sorted it to make it easier to navigate
* Fixed a critical issue regarding replacing runes/infusions which were a part of your bot config (could entirely break bot for that character)
* Fixed an issue with Power level calculation that would break under certain circumstances (most notably dual shields)

Changes in 0.0.6:
* Added ability to configure whether or not certain stop conditions actually stop the bot (Can choose IGNORE/WARN/STOP, WARN stops once only.)
* Adjusted power level calculation to not wildly overstate the effect of crit.

Upcoming Features (in no particular order):
* Companion addons and an integration with this bot to auto-spend levelup points and optimize equipment so you don't have to
* Recognize area damage and avoid standing in it
* Make activatable items a valid choice for combat rotation. Currently items on the hotbar are ignored.
* UI to enable or disable any of the various features I've added so you can customize the way the bot performs.
* Anything else I think of.
* BUG FIXES!

Github: https://github.com/skoobydoo/SkooBot