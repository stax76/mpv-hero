
# mpv-hero-vapoursynth

Branch by [Kris McCann](https://github.com/AJCrowley)

Taken the already amazing [mpv-hero](https://github.com/stax76/mpv-hero) and added:

- Autoloading of current directory to playlist for easy episode navigation when binge watching. The prev/next buttons on the UOSC interface worked, but the keyboard shortcuts for next and prev playlist items didn't, as the playlist wasn't being created. This was just a matter of using [MPV's](https://github.com/mpv-player/mpv) own autoload lua script and adding the flag to use it in the base mpv.conf.

- Added [VapourSynth](https://github.com/vapoursynth/vapoursynth) for high framerate interpolated playback, accessible through either the context menu, the command palette, or keyboard shortcuts. This gives videos buttery smooth playback, sometimes coloquially referred to as "the soap opera effect", as it makes everything much more realistic, which can expose bad special effects, acting, and sets...it can certainly be jarring the first time you experience it,but once you get used to it, it's a far superior viewing experience and hard to go back. My little mini PC handles 1080p videos at 144fps with no issues, but it may not always be desirable to have on (excessive artifacting sometimes when dealing with lots of thin parallel vertical stripes, or struggling with 4k video if your hardware isn't up to the task), so it's just as easy to disable.

- Updated the ```install.bat``` file to add the VapourSynth directory to the %PATH% environment variable, which is necessary for VapourSynth to work. If you choose to move the ```portable_config``` directory to ```%APPDATA%/mpv```, don't forget to update the %PATH% for the VapourSynth directory.

I wrestled for hours to get this working on another mpv distro before finding mpv-hero, which is much more actively maintained, and comes with all of the amazing plugins that you might want (short of VapourSynth). Hopefully this branch fixes that, and I hope that other users are able to enjoy this excellent plugin as I do without having to go through the pains of learning to code for mpv and the various ins and outs of VapourSynth.

Other projects from me
----------------------

A list of my other projects can be found here at [my GitHub page](https://github.com/AJCrowley), and you can contact me at [kris@8pi.ca](kris@8pi.ca).
