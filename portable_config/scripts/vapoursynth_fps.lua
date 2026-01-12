local mp = require 'mp'

-- core function
local function apply_vs_fps(fps)
    mp.set_property_native("vf", {}) -- clear filters
	mp.commandv("vf", "remove", "vapoursynth=~~/VapourSynth/vapoursynth.vpy")
	if fps == 0 then
		os.remove(os.getenv("TEMP") .. "\\mpv_vs_fps.txt")
	else
		local file = io.open(os.getenv("TEMP") .. "\\mpv_vs_fps.txt", "w")
		file:write(tostring(fps))
		file:close()
		mp.commandv("vf", "add", "vapoursynth=~~/VapourSynth/vapoursynth.vpy")
		mp.osd_message("VapourSynth FPS: " .. fps, 2)
	end
end

-- register bindings
local fps_values = {0, 30, 60, 72, 90, 120, 144}

for _, fps in ipairs(fps_values) do
    mp.add_key_binding(
        nil,
        "vapoursynth_fps_" .. fps,
        function() apply_vs_fps(fps) end
    )
end
