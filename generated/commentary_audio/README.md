# VTR Commentary Audio Pack

These `.wav` files were generated locally for the starter commentary actions.
Current active files use `Microsoft Zira Desktop - English (United States)`,
pitch-shifted lower for a male-style commentary voice.

The original unshifted English files are backed up as `*_original.wav`. Upload
the non-`_original` `.wav` files if you want the lower male-style voice.

Roblox cannot play local files from `SoundId`. Upload each `.wav` to Roblox as
an audio asset, then paste the returned asset id into:

`src/shared/CommentaryConfig.lua`

Example:

```lua
{Text = "Goal! A huge finish.", SoundId = "rbxassetid://1234567890"}
```

Use `manifest.json` to match each file to its action and text.
