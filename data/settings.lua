
config.settings.SkooBot = config.settings.SkooBot or {}

if config.settings.SkooBot.bot then return end
config.settings.SkooBot.bot = true

-- Init settings
config.settings.tome.SkooBot = config.settings.tome.SkooBot or {}

if type(config.settings.tome.SkooBot.LOWHEALTH_RATIO) == "nil" then config.settings.tome.SkooBot.LOWHEALTH_RATIO = 0.5 end
if type(config.settings.tome.SkooBot.MAX_INDIVIDUAL_POWER) == "nil" then config.settings.tome.SkooBot.MAX_INDIVIDUAL_POWER = 200 end
if type(config.settings.tome.SkooBot.MAX_DIFF_POWER) == "nil" then config.settings.tome.SkooBot.MAX_DIFF_POWER = 10 end
if type(config.settings.tome.SkooBot.MAX_COMBINED_POWER) == "nil" then config.settings.tome.SkooBot.MAX_COMBINED_POWER = 500 end
if type(config.settings.tome.SkooBot.MAX_ENEMY_COUNT) == "nil" then config.settings.tome.SkooBot.MAX_ENEMY_COUNT = 12 end
if type(config.settings.tome.SkooBot.ACTION_DELAY) == "nil" then config.settings.tome.SkooBot.ACTION_DELAY = 0 end
