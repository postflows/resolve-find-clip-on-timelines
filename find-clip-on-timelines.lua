-- ================================================
-- Find Clip on Timelines
-- Part of PostFlows toolkit for DaVinci Resolve
-- https://github.com/postflows
-- ================================================
--
-- Search and analyze clip usage across project timelines.
-- Includes clip highlighting with color selection and instance counts per timeline.
-- Based on original script by Daniel F. Urdiales, modified by Sergey Knyazkov (2024).
--
-- MIT License
-- Copyright (c) 2024 Daniel F. Urdiales

local resolve = Resolve()
if not resolve then
    print("Error: Resolve API is not available.")
    return
end

local projectManager = resolve:GetProjectManager()
if not projectManager then
    print("Error: Project Manager is not available.")
    return
end

local project = projectManager:GetCurrentProject()
if not project then
    print("Error: No project is open.")
    return
end

local mediaPool = project:GetMediaPool()
if not mediaPool then
    print("Error: Media Pool is not available.")
    return
end

local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)

local winID = "winID"
local fileID = "File"
local findID = "Find"
local treeID = "Timelines_TreeView"
local statID = "Status_Label"
local highlightID = "highlightID"
local colorID = "colorID"

local PRIMARY_COLOR = "#c0c0c0"
local BORDER_COLOR = "#3a6ea5"
local TEXT_COLOR = "#ebebeb"

local PRIMARY_ACTION_BUTTON_STYLE = [[
    QPushButton {
        border: 1px solid #2C6E49;
        max-height: 40px;
        border-radius: 14px;
        background-color: #4C956C;
        color: #FFFFFF;
        min-height: 28px;
        font-size: 16px;
        font-weight: bold;
    }
    QPushButton:hover {
        border: 1px solid ]] .. PRIMARY_COLOR .. [[;
        background-color: #61B15A;
    }
    QPushButton:pressed {
        border: 2px solid ]] .. PRIMARY_COLOR .. [[;
        background-color: #76C893;
    }
]]

local SECONDARY_ACTION_BUTTON_STYLE = [[
    QPushButton {
        border: 1px solid #bc4749;
        max-height: 28px;
        border-radius: 14px;
        background-color: #bc4749;
        color: #FFFFFF;
        min-height: 28px;
        font-size: 13px;
        font-weight: bold;
    }
    QPushButton:hover {
        border: 1px solid ]] .. PRIMARY_COLOR .. [[;
        background-color: #f07167;
    }
    QPushButton:pressed {
        border: 2px solid ]] .. PRIMARY_COLOR .. [[;
        background-color: #D00000;
    }
]]

local THIRD_ACTION_BUTTON_STYLE = [[
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
]]

local START_LOGO_CSS = [[
    QLabel {
        color: #62b6cb;
        font-size: 22px;
        font-weight: bold;
        letter-spacing: 1px;
        font-family: 'Futura';
    }
]]

local END_LOGO_CSS = [[
    QLabel {
        color: rgb(255, 255, 255);
        font-size: 22px;
        font-weight: bold;
        letter-spacing: 1px;
        font-family: 'Futura';
    }
]]

local COMBOBOX_STYLE = [[
    QComboBox {
        border: 1px solid ]] .. BORDER_COLOR .. [[;
        border-radius: 4px;
        padding: 4px 8px;
        color: ]] .. TEXT_COLOR .. [[;
        background-color: #2d2d2d;
        max-height: 28px;
        font-size: 12px;
        min-width: 100px;
    }
    QComboBox::drop-down {
        border: 0px;
        width: 20px;
        background: transparent;
    }
    QComboBox::down-arrow {
        width: 12px;
        height: 12px;
        background: ]] .. PRIMARY_COLOR .. [[;
        border-radius: 2px;
    }
    QComboBox QAbstractItemView {
        border: 1px solid ]] .. BORDER_COLOR .. [[;
        background-color: #2d2d2d;
        color: ]] .. TEXT_COLOR .. [[;
        selection-background-color: ]] .. PRIMARY_COLOR .. [[;
        outline: none;
        min-height: 24px;
    }
    QComboBox:hover {
        border-color: ]] .. PRIMARY_COLOR .. [[;
    }
    QComboBox:focus {
        border-color: ]] .. PRIMARY_COLOR .. [[;
    }
]]

local AVAILABLE_COLORS = {"Orange", "Apricot", "Yellow", "Lime", "Olive", "Green", "Teal", "Navy", "Blue", "Purple", "Violet", "Pink", "Tan", "Beige", "Brown", "Chocolate"}

local currentClipId = nil
local defaultClipName = ""
local foundClips = {}

-- Check selected clip in Media Pool
local selectedClips = mediaPool:GetSelectedClips()
if selectedClips and #selectedClips > 0 then
    local firstSelected = selectedClips[1]
    defaultClipName = firstSelected:GetName()
    local ok, uid = pcall(function() return firstSelected:GetUniqueId() end)
    if ok and uid then
        currentClipId = uid
    else
        print("Error: Cannot get UniqueId for selected clip.")
    end
end

-- Close existing window if open
local existingWin = ui:FindWindow(winID)
if existingWin then
    existingWin:Show()
    existingWin:Raise()
    return
end

-- UI Layout
local layout = ui:VGroup(
    {ID = "root"},
    {
        ui:HGroup({
            ui:Label({Weight = 0, Text = "Find", StyleSheet = START_LOGO_CSS}),
            ui:Label({Weight = 0, Text = "Clip in timelines", StyleSheet = END_LOGO_CSS, Margin = -1.5})
        }),
        ui:VGap(3),
        ui:HGroup(
            {Weight = 2, Spacing = 5},
            {
                ui:LineEdit({
                    ID = fileID,
                    PlaceholderText = "Enter clip to search.",
                    Text = defaultClipName,
                    MinimumSize = {200, 24},
                    Weight = 1.5
                }),
                ui:Button({
                    ID = "refreshID",
                    Text = "Refresh",
                    MinimumSize = {100, 30},
                    StyleSheet = SECONDARY_ACTION_BUTTON_STYLE,
                    Weight = 0.5
                })
            }
        ),
        ui:VGap(3),
        ui:HGroup(
            {Weight = 0, Spacing = 5},
            {
                ui:Button({
                    ID = findID,
                    Text = "Search",
                    MinimumSize = {100, 30},
                    StyleSheet = PRIMARY_ACTION_BUTTON_STYLE,
                    Weight = 0.5
                }),
                ui:Button({
                    ID = highlightID,
                    Text = "Highlight Clips",
                    MinimumSize = {100, 30},
                    StyleSheet = THIRD_ACTION_BUTTON_STYLE,
                    Weight = 0.5
                }),
                ui:ComboBox({
                    ID = colorID,
                    StyleSheet = COMBOBOX_STYLE,
                    Weight = 0.5,
                    Enabled = true,
                    Editable = false,
                    Events = {CurrentIndexChanged = true}
                })
            }
        ),
        ui:VGap(3),
        ui:HGroup(
            {Weight = 3},
            {
                ui:Tree({
                    ID = treeID,
                    AlternatingRowColors = true,
                    RootIsDecorated = false,
                    SortingEnabled = true,
                    ToolTip = "Double click timeline to open.",
                    Events = {ItemDoubleClicked = true}
                })
            }
        ),
        ui:VGap(3),
        ui:HGroup(
            {Weight = 0},
            {ui:Label({ID = statID})}
        )
    }
)

local win = disp:AddWindow(
    {
        ID = winID,
        WindowTitle = "Find Clip Usage",
        Events = {Close = true},
        FixedSize = {450, 400}
    },
    layout
)

local winItems = win:GetItems()

local function initTree()
    local tree = winItems[treeID]
    tree.ColumnCount = 2
    local hdr = tree:NewItem()
    hdr.Text[0] = "Timeline Name"
    hdr.Text[1] = "Clip Count"
    tree:SetHeaderItem(hdr)
    tree.ColumnWidth[0] = 300
    tree.ColumnWidth[1] = 120
end

local function initComboBox()
    local combo = winItems[colorID]
    combo:Clear()
    for _, color in ipairs(AVAILABLE_COLORS) do
        combo:AddItem(color)
    end
    combo.CurrentText = "Yellow"
end

local function searchTimeline(timelineObj, clipId, collectClips)
    if not timelineObj then
        if collectClips then
            return false, {video = 0, audio = 0, linked = 0}, {}
        else
            return false, {video = 0, audio = 0, linked = 0}, nil
        end
    end

    local videoClips = {}
    local audioClips = {}
    local linkedPairs = 0
    local foundList = {}

    local videoTrackCount = timelineObj:GetTrackCount("video")
    for trackIndex = 1, videoTrackCount do
        local items = timelineObj:GetItemsInTrack("video", trackIndex)
        if items then
            for clipIndex, clip in pairs(items) do
                local mediaPoolItem = clip:GetMediaPoolItem()
                if mediaPoolItem then
                    local ok, uid = pcall(function() return mediaPoolItem:GetUniqueId() end)
                    if ok and uid == clipId then
                        local start = clip:GetStart()
                        videoClips[start] = {
                            clip = clip,
                            ["end"] = clip:GetEnd(),
                            track = trackIndex,
                            color = clip:GetClipColor()
                        }
                    end
                end
            end
        end
    end

    local audioTrackCount = timelineObj:GetTrackCount("audio")
    for trackIndex = 1, audioTrackCount do
        local items = timelineObj:GetItemsInTrack("audio", trackIndex)
        if items then
            for clipIndex, clip in pairs(items) do
                local mediaPoolItem = clip:GetMediaPoolItem()
                if mediaPoolItem then
                    local ok, uid = pcall(function() return mediaPoolItem:GetUniqueId() end)
                    if ok and uid == clipId then
                        local start = clip:GetStart()
                        audioClips[start] = {
                            clip = clip,
                            ["end"] = clip:GetEnd(),
                            track = trackIndex,
                            color = clip:GetClipColor()
                        }
                    end
                end
            end
        end
    end

    local linkedStarts = {}
    for start, _ in pairs(videoClips) do
        if audioClips[start] and videoClips[start]["end"] == audioClips[start]["end"] then
            linkedStarts[start] = true
            linkedPairs = linkedPairs + 1
        end
    end

    local videoCount = 0
    for start, _ in pairs(videoClips) do
        if not linkedStarts[start] then videoCount = videoCount + 1 end
    end
    local audioCount = 0
    for start, _ in pairs(audioClips) do
        if not linkedStarts[start] then audioCount = audioCount + 1 end
    end

    if collectClips then
        for start, clipInfo in pairs(videoClips) do
            if not linkedStarts[start] then
                table.insert(foundList, {
                    clip = clipInfo.clip,
                    track_type = "video",
                    track_index = clipInfo.track,
                    original_color = clipInfo.color
                })
            end
        end
        for start, clipInfo in pairs(audioClips) do
            if not linkedStarts[start] then
                table.insert(foundList, {
                    clip = clipInfo.clip,
                    track_type = "audio",
                    track_index = clipInfo.track,
                    original_color = clipInfo.color
                })
            end
        end
        for start, _ in pairs(linkedStarts) do
            table.insert(foundList, {
                clip = videoClips[start].clip,
                track_type = "video+audio",
                track_index = videoClips[start].track,
                original_color = videoClips[start].color
            })
        end
    end

    local found = (videoCount > 0 or audioCount > 0 or linkedPairs > 0)
    local counts = {video = videoCount, audio = audioCount, linked = linkedPairs}
    if collectClips then
        return found, counts, foundList
    else
        return found, counts, nil
    end
end

local function onFind(ev)
    if not currentClipId then
        winItems[statID].Text = "No clip selected or clip ID is invalid."
        return
    end

    winItems[treeID]:Clear()
    initTree()
    foundClips = {}

    local ok, totalTimelines = pcall(function() return project:GetTimelineCount() end)
    if not ok or not totalTimelines then
        winItems[statID].Text = "Error: Cannot get timeline count."
        return
    end

    local totalClipsFound = 0
    for idx = 1, totalTimelines do
        winItems[statID].Text = string.format("Searching %d/%d Timelines.", idx, totalTimelines)
        local timelineObj = project:GetTimelineByIndex(idx)
        local found, counts, _ = searchTimeline(timelineObj, currentClipId, false)

        if found then
            local item = winItems[treeID]:NewItem()
            item.Text[0] = timelineObj:GetName()
            item.Text[1] = string.format("V:%d A:%d L:%d", counts.video, counts.audio, counts.linked)
            item:SetData(0, "DisplayRole", idx)
            winItems[treeID]:AddTopLevelItem(item)
            totalClipsFound = totalClipsFound + counts.video + counts.audio + counts.linked
        end
    end

    local topCount = winItems[treeID]:TopLevelItemCount()
    winItems[statID].Text = string.format("Clip was found on %d Timelines. Total instances: %d.", topCount, totalClipsFound)
end

local function onHighlight(ev)
    local selectedItem = winItems[treeID]:CurrentItem()
    if not selectedItem then
        winItems[statID].Text = "Select a timeline to highlight clips."
        return
    end

    local timelineIndex = selectedItem:GetData(0, "DisplayRole")
    if not timelineIndex then
        winItems[statID].Text = "Invalid timeline selected."
        return
    end

    local timelineObj = project:GetTimelineByIndex(timelineIndex)
    if not timelineObj then
        winItems[statID].Text = "Error: Cannot access selected timeline."
        return
    end

    local _, _, clips = searchTimeline(timelineObj, currentClipId, true)
    if not clips or #clips == 0 then
        winItems[statID].Text = "No clips found in selected timeline."
        return
    end

    local color = winItems[colorID].CurrentText
    local successCount = 0

    for _, clipInfo in ipairs(clips) do
        local ok, err = pcall(function()
            local clip = clipInfo.clip
            if clip and clip.SetClipColor then
                clip:SetClipColor(color)
                successCount = successCount + 1
            end
        end)
        if not ok then
            print("Error setting color for clip in " .. timelineObj:GetName() .. ": " .. tostring(err))
        end
    end

    foundClips[timelineIndex] = clips
    winItems[statID].Text = string.format("Highlighted %d/%d clips in %s with %s.", successCount, #clips, selectedItem.Text[0], color)
end

local function onColorChanged(ev)
    local color = winItems[colorID].CurrentText
    print("ComboBox changed to: " .. tostring(color))
end

local function refreshClip(ev)
    local selected = mediaPool:GetSelectedClips()
    if selected and #selected > 0 then
        local sel = selected[1]
        local ok, uid = pcall(function() return sel:GetUniqueId() end)
        if ok and uid then
            winItems[fileID].Text = sel:GetName()
            currentClipId = uid
        else
            print("Error: Cannot get UniqueId for selected clip.")
            winItems[fileID].Text = ""
            currentClipId = nil
        end
    else
        winItems[fileID].Text = ""
        currentClipId = nil
    end
end

local function setTimeline(ev)
    local item = ev and ev.item
    if not item then return end
    local timelineIndex = item:GetData(0, "DisplayRole")
    if not timelineIndex then return end

    local tl = project:GetTimelineByIndex(timelineIndex)
    if not tl then
        winItems[statID].Text = "Error: Timeline not found."
        return
    end
    local ok, err = pcall(function()
        local currentPage = resolve:GetCurrentPage()
        if currentPage == "media" or currentPage == "fusion" then
            resolve:OpenPage("edit")
        end
        project:SetCurrentTimeline(tl)
    end)
    if not ok then
        print("Error: Cannot set timeline at index " .. tostring(timelineIndex) .. ": " .. tostring(err))
        winItems[statID].Text = "Error: Cannot open selected timeline."
    else
        winItems[statID].Text = "Switched to timeline: " .. (tl:GetName() or "?")
    end
end

local function onClose(ev)
    win:Hide()
    disp:ExitLoop()
end

win.On[treeID].ItemDoubleClicked = setTimeline
win.On[findID].Clicked = onFind
win.On[highlightID].Clicked = onHighlight
win.On[colorID].CurrentIndexChanged = onColorChanged
win.On["refreshID"].Clicked = refreshClip
win.On[winID].Close = onClose

initTree()
initComboBox()

win:Show()
disp:RunLoop()
