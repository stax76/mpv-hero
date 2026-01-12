-- cleanup.lua
local utils = require 'mp.utils'

mp.register_event("shutdown", function()
    local temp_dir = os.getenv("TEMP") or os.getenv("TMP")
    if temp_dir then
        local file_path = temp_dir .. "\\mpv_vs_fps.txt"
        os.remove(file_path)
    end
end)
