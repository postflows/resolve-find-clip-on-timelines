# ================================================
# Find Clip on Timelines
# Part of PostFlows toolkit for DaVinci Resolve
# https://github.com/postflows
# ================================================

# This script provides a custom User Interface (UI) for searching and analyzing clip usage in a DaVinci Resolve project.
# Includes clip highlighting functionality with color selection and displays the number of clip instances per timeline.
# Based on original script by Daniel F. Urdiales, modified by Sergey Knyazkov (2024)

# MIT License
# Copyright (c) 2024 Daniel F. Urdiales

ui = fusion.UIManager
dispatcher = bmd.UIDispatcher(ui)

# Initialize Resolve objects with error handling
if not resolve:
    print("Error: Resolve API is not available.")
    exit()
project_manager = resolve.GetProjectManager()
if not project_manager:
    print("Error: Project Manager is not available.")
    exit()
project = project_manager.GetCurrentProject()
if not project:
    print("Error: No project is open.")
    exit()
mediapool = project.GetMediaPool()
if not mediapool:
    print("Error: Media Pool is not available.")
    exit()
timeline = project.GetCurrentTimeline()

winID = 'winID'
fileID = 'File'
findID = 'Find'
treeID = 'Timelines_TreeView'
statID = 'Status_Label'
highlightID = 'highlightID'
colorID = 'colorID'

# Define colors for styling from Clip Marker Tool v1_3.py
PRIMARY_COLOR = "#c0c0c0"
HOVER_COLOR = "#f26419"
BORDER_COLOR = "#3a6ea5"
TEXT_COLOR = "#ebebeb"

# Button styles from Clip Marker Tool v1_3.py
PRIMARY_ACTION_BUTTON_STYLE = f"""
    QPushButton {{
        border: 1px solid #2C6E49;
        max-height: 40px;
        border-radius: 14px;
        background-color: #4C956C;
        color: #FFFFFF;
        min-height: 28px;
        font-size: 16px;
        font-weight: bold;
    }}
    QPushButton:hover {{
        border: 1px solid {PRIMARY_COLOR};
        background-color: #61B15A;
    }}
    QPushButton:pressed {{
        border: 2px solid {PRIMARY_COLOR};
        background-color: #76C893;
    }}
"""

SECONDARY_ACTION_BUTTON_STYLE = f"""
    QPushButton {{
        border: 1px solid #bc4749;
        max-height: 28px;
        border-radius: 14px;
        background-color: #bc4749;
        color: #FFFFFF;
        min-height: 28px;
        font-size: 13px;
        font-weight: bold;
    }}
    QPushButton:hover {{
        border: 1px solid {PRIMARY_COLOR};
        background-color: #f07167;
    }}
    QPushButton:pressed {{
        border: 2px solid {PRIMARY_COLOR};
        background-color: #D00000;
    }}
"""

THIRD_ACTION_BUTTON_STYLE = """
    QPushButton {
        border: 1px solid rgb(71,91,98);
        max-height: 28px;
        border-radius: 14px;
        background-color: rgb(71,91,98);
        color: rgb(255, 255, 255);
        min-height: 28px;
        font-size: 13px;
    }
    QPushButton:hover {
        border: 1px solid rgb(176,176,176);
        background-color: rgb(89,90,183);
    }
    QPushButton:pressed {
        border: 2px solid rgb(119,121,252);
        background-color: rgb(119,121,252);
    }
    QPushButton:disabled {
        border: 2px solid rgb(124,125,255);
        background-color: rgb(124,125,255);
        color: rgb(150, 150, 150);
    }
"""
START_LOGO_CSS = """
    QLabel {
        color: #62b6cb;
        font-size: 22px;
        font-weight: bold;
        letter-spacing: 1px;
        font-family: 'Futura';
    }
"""

END_LOGO_CSS = """
    QLabel {
        color: rgb(255, 255, 255);
        font-size: 22px;
        font-weight: bold;
        letter-spacing: 1px;
        font-family: 'Futura';
    }
"""
# ComboBox style
COMBOBOX_STYLE = f"""
    QComboBox {{
        border: 1px solid {BORDER_COLOR};
        border-radius: 4px;
        padding: 4px 8px;
        color: {TEXT_COLOR};
        background-color: #2d2d2d;
        max-height: 28px;
        font-size: 12px;
        min-width: 100px;
    }}
    QComboBox::drop-down {{
        border: 0px;
        width: 20px;
        background: transparent;
    }}
    QComboBox::down-arrow {{
        width: 12px;
        height: 12px;
        background: {PRIMARY_COLOR};
        border-radius: 2px;
    }}
    QComboBox QAbstractItemView {{
        border: 1px solid {BORDER_COLOR};
        background-color: #2d2d2d;
        color: {TEXT_COLOR};
        selection-background-color: {PRIMARY_COLOR};
        outline: none;
        min-height: 24px;
    }}
    QComboBox:hover {{
        border-color: {PRIMARY_COLOR};
    }}
    QComboBox:focus {{
        border-color: {PRIMARY_COLOR};
    }}
"""

# Available colors based on the screenshot
AVAILABLE_COLORS = ['Orange', 'Apricot', 'Yellow', 'Lime', 'Olive', 'Green', 'Teal', 'Navy', 'Blue', 'Purple', 'Violet', 'Pink', 'Tan', 'Beige', 'Brown', 'Chocolate']

# Global Variables
current_clip_id = None
default_clip_name = ''
found_clips = {}  # {timeline_index: [list of {'clip': TimelineItem, 'track_type': str, 'track_index': int, 'original_color': str}]}

# Check selected clip
selected_clips = mediapool.GetSelectedClips()
if selected_clips:
    first_selected_clip = selected_clips[0]
    default_clip_name = first_selected_clip.GetName()
    try:
        current_clip_id = first_selected_clip.GetUniqueId()
    except AttributeError:
        print("Error: Cannot get UniqueId for selected clip.")
        current_clip_id = None

# Close existing window if open
win = ui.FindWindow(winID)
if win:
    win.Show()
    win.Raise()
    exit()

# UI Layout setup
layout = ui.VGroup(
    {'ID': 'root'},
    [
        ui.HGroup([
            ui.Label({"Weight": 0, "Text": "Find", "StyleSheet": START_LOGO_CSS}),
            ui.Label({"Weight": 0, "Text": "Clip in timelines", "StyleSheet": END_LOGO_CSS, "Margin": -1.5}),
        ]),
        ui.VGap(3),
        ui.HGroup(
            {'Weight': 2, 'Spacing': 5},
            [
                ui.LineEdit({
                    'ID': fileID,
                    'PlaceholderText': 'Enter clip to search.',
                    'Text': default_clip_name,
                    'MinimumSize': (200, 24),
                    'Weight': 1.5
                }),
                ui.Button({
                    'ID': 'refreshID',
                    'Text': 'Refresh',
                    'MinimumSize': (100, 30),
                    'StyleSheet': SECONDARY_ACTION_BUTTON_STYLE,
                    'Weight': 0.5
                }),
            ]
        ),
        ui.VGap(3),
        ui.HGroup(
            {'Weight': 0, 'Spacing': 5},
            [
                ui.Button({
                    'ID': findID,
                    'Text': 'Search',
                    'MinimumSize': (100, 30),
                    'StyleSheet': PRIMARY_ACTION_BUTTON_STYLE,
                    'Weight': 0.5
                }),
                ui.Button({
                    'ID': highlightID,
                    'Text': 'Highlight Clips',
                    'MinimumSize': (100, 30),
                    'StyleSheet': THIRD_ACTION_BUTTON_STYLE,
                    'Weight': 0.5
                }),
                ui.ComboBox({
                    'ID': colorID,
                    'StyleSheet': COMBOBOX_STYLE,
                    'Weight': 0.5,
                    'Enabled': True,
                    'Editable': False,
                    'Events': {'CurrentIndexChanged': True}
                }),
            ]
        ),
        ui.VGap(3),
        ui.HGroup(
            {'Weight': 3},
            [
                ui.Tree({
                    'ID': treeID,
                    'AlternatingRowColors': True,
                    'RootIsDecorated': False,
                    'SortingEnabled': True,
                    'ToolTip': 'Double click timeline to open.',
                    'Events': {'ItemDoubleClicked': True}
                })
            ]
        ),
        ui.VGap(3),
        ui.HGroup(
            {'Weight': 0},
            [
                ui.Label({'ID': statID}),
            ]
        ),
    ]
)

# Create the window
win = dispatcher.AddWindow(
    {
        'ID': winID,
        'WindowTitle': 'Find Clip on Timelines',
        'Events': {'Close': True},
        'FixedSize': (450, 400)
    },
    layout
)

win_items = win.GetItems()

# Initialize Tree with headers
def init_tree():
    tree = win_items[treeID]
    tree.ColumnCount = 2  # Two columns: Timeline Name and Clip Count
    tree.SetHeaderLabels(["Timeline Name", "Clip Count"])  # Set column headers
    tree.ColumnWidth[0] = 300  # Width for Timeline Name
    tree.ColumnWidth[1] = 120  # Increased width for Clip Count to accommodate (V+A)
    print("Tree initialized with headers: Timeline Name, Clip Count")  # Debugging

# Initialize ComboBox with colors
def init_combo_box():
    combo = win_items[colorID]
    combo.Clear()
    for color in AVAILABLE_COLORS:
        combo.AddItem(color)
        print(f"Added color to ComboBox: {color}")  # Debugging
    combo.CurrentText = 'Yellow'

# Function to search clip by its ID in a timeline
def search_timeline(timeline, clip_id, collect_clips=False):
    if not timeline:
        return False, {'video': 0, 'audio': 0, 'linked': 0}, [] if collect_clips else None
    
    video_clips = {}  # {start_frame: clip_info}
    audio_clips = {}  # {start_frame: clip_info}
    linked_pairs = 0
    found_clips = []
    
    # Search for video clips
    for track_index in range(1, timeline.GetTrackCount('video') + 1):
        for clip in timeline.GetItemListInTrack('video', track_index):
            media_pool_item = clip.GetMediaPoolItem()
            if media_pool_item and media_pool_item.GetUniqueId() == clip_id:
                start = clip.GetStart()
                video_clips[start] = {
                    'clip': clip,
                    'end': clip.GetEnd(),
                    'track': track_index,
                    'color': clip.GetClipColor()
                }
    
    # Search for audio clips
    for track_index in range(1, timeline.GetTrackCount('audio') + 1):
        for clip in timeline.GetItemListInTrack('audio', track_index):
            media_pool_item = clip.GetMediaPoolItem()
            if media_pool_item and media_pool_item.GetUniqueId() == clip_id:
                start = clip.GetStart()
                audio_clips[start] = {
                    'clip': clip,
                    'end': clip.GetEnd(),
                    'track': track_index,
                    'color': clip.GetClipColor()
                }
    
    # Determine linked pairs
    linked_starts = set()
    for start in video_clips:
        if start in audio_clips and video_clips[start]['end'] == audio_clips[start]['end']:
            linked_starts.add(start)
            linked_pairs += 1
    
    # Prepare results
    video_count = len(video_clips) - linked_pairs
    audio_count = len(audio_clips) - linked_pairs
    
    if collect_clips:
        # Collect all clips for highlighting
        for start, clip_info in video_clips.items():
                if start not in linked_starts:  # Video only
                found_clips.append({
                    'clip': clip_info['clip'],
                    'track_type': 'video',
                    'track_index': clip_info['track'],
                    'original_color': clip_info['color']
                })
        
        for start, clip_info in audio_clips.items():
                if start not in linked_starts:  # Audio only
                found_clips.append({
                    'clip': clip_info['clip'],
                    'track_type': 'audio',
                    'track_index': clip_info['track'],
                    'original_color': clip_info['color']
                })
        
        # Add one from each linked pair (to avoid duplicates)
        for start in linked_starts:
            found_clips.append({
                'clip': video_clips[start]['clip'],
                'track_type': 'video+audio',
                'track_index': video_clips[start]['track'],
                'original_color': video_clips[start]['color']
            })
    
    return (video_count > 0 or audio_count > 0 or linked_pairs > 0, 
            {'video': video_count, 'audio': audio_count, 'linked': linked_pairs},
            found_clips if collect_clips else None)

# Find button handler
# Find button handler
def on_find(ev):
    global current_clip_id, found_clips
    if not current_clip_id:
        win_items[statID].Text = "No clip selected or clip ID is invalid."
        return

    win_items[treeID].Clear()
    found_clips.clear()
    try:
        total_timelines = project.GetTimelineCount()
    except AttributeError:
        win_items[statID].Text = "Error: Cannot get timeline count."
        return

    total_clips_found = 0
    for idx in range(1, total_timelines + 1):
        win_items[statID].Text = f'Searching {idx}/{total_timelines} Timelines.'
        timeline = project.GetTimelineByIndex(idx)
        found, counts, _ = search_timeline(timeline, current_clip_id)
        
        if found:
            item = win_items[treeID].NewItem()
            item.Text[0] = timeline.GetName()
            item.Text[1] = f"V:{counts['video']} A:{counts['audio']} L:{counts['linked']}"
            item.SetData(0, 'TimelineIndex', idx)
            win_items[treeID].AddTopLevelItem(item)
            # Total count: video + audio + linked pairs (as 1 item each)
            total_clips_found += counts['video'] + counts['audio'] + counts['linked']
    
    win_items[statID].Text = f'Clip was found on {win_items[treeID].TopLevelItemCount()} Timelines. Total instances: {total_clips_found}.'

# Highlight clips handler - полностью переработанная версия
def on_highlight(ev):
    global found_clips
    selected_item = win_items[treeID].CurrentItem()
    if not selected_item:
        win_items[statID].Text = "Select a timeline to highlight clips."
        return
    
    timeline_index = selected_item.GetData(0, 'TimelineIndex')
    if not timeline_index:
        win_items[statID].Text = "Invalid timeline selected."
        return
    
    timeline = project.GetTimelineByIndex(timeline_index)
    if not timeline:
        win_items[statID].Text = "Error: Cannot access selected timeline."
        return

    # Get clips for highlighting
    _, _, clips = search_timeline(timeline, current_clip_id, collect_clips=True)
    if not clips:
        win_items[statID].Text = "No clips found in selected timeline."
        return

    color = win_items[colorID].CurrentText
    success_count = 0
    
    for clip_info in clips:
        try:
            clip = clip_info['clip']
            if clip and hasattr(clip, 'SetClipColor'):
                clip.SetClipColor(color)
                success_count += 1
            else:
                print(f"Warning: Invalid clip object in {timeline.GetName()}")
        except Exception as e:
            print(f"Error setting color for clip in {timeline.GetName()}: {str(e)}")
            continue

    # Store clips for possible original color restore
    found_clips[timeline_index] = clips
    win_items[statID].Text = f"Highlighted {success_count}/{len(clips)} clips in {selected_item.Text[0]} with {color}."

# ComboBox change handler for debugging
def on_color_changed(ev):
    color = win_items[colorID].CurrentText
    print(f"ComboBox changed to: {color}")

# Refresh clip function
def refresh_clip(ev):
    global current_clip_id
    selected_clips = mediapool.GetSelectedClips()
    if selected_clips:
        selected_clip = selected_clips[0]
        try:
            win_items[fileID].Text = selected_clip.GetName()
            current_clip_id = selected_clip.GetUniqueId()
        except AttributeError:
            print("Error: Cannot get UniqueId for selected clip.")
            win_items[fileID].Text = ""
            current_clip_id = None
    else:
        win_items[fileID].Text = ""
        current_clip_id = None

# Set selected timeline
def set_timeline(ev):
    timeline_index = ev['item'].GetData(0, 'TimelineIndex')
    if timeline_index:
        try:
            if resolve.GetCurrentPage() in ['media', 'fusion']:
                resolve.OpenPage('edit')
            project.SetCurrentTimeline(project.GetTimelineByIndex(timeline_index))
        except AttributeError:
            print(f"Error: Cannot set timeline at index {timeline_index}.")
            win_items[statID].Text = "Error: Cannot open selected timeline."

# Close event handler
def on_close(ev):
    win.Hide()
    dispatcher.ExitLoop()

# Event bindings
win.On[treeID].ItemDoubleClicked = set_timeline
win.On[findID].Clicked = on_find
win.On[highlightID].Clicked = on_highlight
win.On[colorID].CurrentIndexChanged = on_color_changed
win.On['refreshID'].Clicked = refresh_clip
win.On[winID].Close = on_close

# Initialize UI
init_tree()
init_combo_box()

# Run the UI loop
win.Show()
dispatcher.RunLoop()