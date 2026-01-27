local mp = require 'mp'

-- core function
function vapoursynth_set_fps(fps)
    --mp.set_property_native("vf", {}) -- clear filters
	mp.msg.info("VapourSynth FPS script called: " .. fps)
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

mp.register_script_message("vapoursynth_set_fps", function(fps)
    vapoursynth_set_fps(tonumber(fps) or 0)
end)

-- clean up on close
mp.register_event("shutdown", function()
    local temp_dir = os.getenv("TEMP") or os.getenv("TMP")
    if temp_dir then
        local file_path = temp_dir .. "\\mpv_vs_fps.txt"
        os.remove(file_path)
    end
end)
