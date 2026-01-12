# VAPOURSYNTH FRAME INTERPOLATION SCRIPT
# Kris McCann (kris@8pi.ca) 2026

import vapoursynth as vs
import os

script_directory = os.path.dirname(os.path.abspath(__file__))
core = vs.core
core.num_threads = 0

try:
    temp_path = os.path.join(os.environ["TEMP"], "mpv_vs_fps.txt")
    with open(temp_path, "r") as f:
        target_fps_str = f.read().strip()
        target_fps = int(target_fps_str)  # Try to convert to int
except (FileNotFoundError, KeyError, ValueError):
    # If any error, just pass through the original video unchanged
    raise ValueError(f"VPY filter: Invalid or missing FPS file. Aborting. Error: {e}")
else:
		
	if not hasattr(core,'svp1'):
		core.std.LoadPlugin(os.path.join(script_directory, "svpflow1_vs64.dll"))
	if not hasattr(core,'svp2'):
		core.std.LoadPlugin(os.path.join(script_directory, "svpflow2_vs64.dll"))

	clip = video_in

	super_params     = "{pel:2, gpu:1, full:true, scale:{up:2, down:4}, rc:0}"

	analyse_params   = "{gpu:1, vectors:3, main:{levels:0, search:{type:4, distance:-4, sort:true, satd:false, coarse:{width:1050, type:4, distance:0, satd:true, trymany:false, bad:{sad:1000, range:-24}}}, penalty:{lambda:10.0, plevel:1.5, lsad:8000, pnew:50, pglobal:50, pzero:100, pnbour:50, prev:0}}, refine:[{thsad:200, search:{type:4, distance:2, satd:false}, penalty:{pnew:50}}], special:{delta:1}}}"

	smoothfps_params = "{rate:{num:" + str(target_fps) + ", den:1, abs:true}, algo:23, block:false, cubic:1, gpuid:11, linear: true, mask:{cover:100, area:0, area_sharp:1.0}, scene:{mode:3, blend:true, limits:{m1:1600, m2:2800, scene:4000, zero:200, blocks:20}, luma:1.5},light:{aspect:0.0, sar:1.0, zoom:0.0, lights:16, length:100, cell:1.0, border:12}}"

	src_fps     = container_fps if container_fps>0.1 else 23.976
	stereo_type = 0

	def interpolate(clip):
		input_um = clip.resize.Point(format=vs.YUV420P10,dither_type="random")
		input_m = input_um
		input_m = input_m.std.CropRel(4,4,0,0)
		input_m8 = input_m.resize.Point(format=vs.YUV420P8)

		super   = core.svp1.Super(input_m8,super_params)
		vectors = core.svp1.Analyse(super["clip"],super["data"],input_m8,analyse_params)
		smooth  = core.svp2.SmoothFps(input_m,super["clip"],super["data"],vectors["clip"],vectors["data"],smoothfps_params,src=input_um,fps=src_fps)
		
		return smooth

	if stereo_type == 1:
		lf = interpolate(core.std.CropRel(clip,0,(int)(clip.width/2),0,0))
		rf = interpolate(core.std.CropRel(clip,(int)(clip.width/2),0,0,0))
		smooth = core.std.StackHorizontal([lf, rf])
	elif stereo_type == 2:
		lf = interpolate(core.std.CropRel(clip,0,0,0,(int)(clip.height/2)))
		rf = interpolate(core.std.CropRel(clip,0,0,(int)(clip.height/2),0))
		smooth = core.std.StackVertical([lf, rf])
	else:
		smooth =  interpolate(clip)

	smooth.set_output()