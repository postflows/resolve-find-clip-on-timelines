# Find Clip on Timelines

> Part of [PostFlows](https://github.com/postflows) toolkit for DaVinci Resolve

Search for a clip across all timelines and optionally highlight its instances with a chosen clip color. **Lua** script (canonical version).

## What it does

Uses currently selected clip in Media Pool (or manual refresh). Searches all project timelines by clip UniqueId, shows timeline list with V/A/L counts. User can double-click to open a timeline and use Highlight to set clip color on instances.

## Requirements

- DaVinci Resolve 18+
- Open project

## Installation

Copy the **`find-clip-on-timelines.lua`** file to:

- **macOS:** `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/`
- **Windows:** `C:\ProgramData\Blackmagic Design\DaVinci Resolve\Fusion\Scripts\`

Run from **Workspace → Scripts** in Resolve (or from the Fusion page Scripts menu).

## Usage

Select a clip in Media Pool (or type name and refresh). Click Search. Select timeline in list, choose color, click Highlight Clips. Double-click timeline to open it.

## License

MIT © PostFlows
