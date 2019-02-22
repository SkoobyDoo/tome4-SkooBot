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

Changes in 0.0.11
* Fixed some conditions where the bot would stop running for no good reason.

Changes in 0.0.10
* Fixed lore dialog hiding to not disable tooltips
* Fixed lua error when mousing over enemies you couldn't see (stealth enemies; player blind)
* Added ability to configure a delay for the bot to wait before each action. This is currently a bit buggy and occasionally gets stuck or acts extra times (Seems to be tied to moving the mouse..?)
* the default delay is 0 and when set to zero the bot performs exactly as before (...I think)

Upcoming Features (in no particular order):
* Companion addons and an integration with this bot to auto-spend levelup points and optimize equipment so you don't have to
* Recognize area damage and avoid standing in it
* Make activatable items a valid choice for combat rotation. Currently items on the hotbar are ignored.
* UI to enable or disable any of the various features I've added so you can customize the way the bot performs.
* Anything else I think of.
* BUG FIXES!

Github: https://github.com/skoobydoo/SkooBot