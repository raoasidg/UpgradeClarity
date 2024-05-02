local _, namespace = ...
namespace.localizations = {}

-- Local references
local localizations = namespace.localizations

local setmetatable, tostring =
      setmetatable, tostring

local API_GetLocale = GetLocale

local client_locale = API_GetLocale()
if client_locale == "enGB" then client_locale = "enUS" end

setmetatable(localizations, {
    __call = function(_, locale)
        localizations[locale] = {}
        return localizations[locale]
    end,
    __index = function(_, key)
        return localizations[client_locale] and localizations[client_locale][key] or localizations.enUS[key] or tostring(key)
    end,
})
