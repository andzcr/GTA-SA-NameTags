script_author('Andrei')
script_name('Nametags')
local memory = require('memory')
local imgui = require('mimgui')
require 'lib.moonloader'
local ffi = require "ffi"
local vector3d = require('vector3d')

local slider = imgui.new.int(25)
local healthpicker = imgui.new.float[4](255, 255, 255, 0)
local renderWindow = imgui.new.bool()
local afks = 0
local afkpng = afkpng
local rot1, rot2 = 8, 7

local pathconfig = getWorkingDirectory() .. "\\resources\\visualtags\\config.json"
if not doesFileExist(pathconfig) then
	createDirectory(getWorkingDirectory() .. "\\resources\\visualtags\\")
    local cfg = {
        background = true,
        isWhite = false,
        distance = 25,
        showid = true,
        showHealth = true,
        showAfk = true,
        r = 255,
        g = 255,
        b = 255
    }
    healthpicker[0], healthpicker[1], healthpicker[2] = cfg.r, cfg.g, cfg.b
    config = cfg
    local file = io.open(pathconfig, "wb")
	file:write(encodeJson(cfg))
    file:flush()
	file:close()
else
    local file = io.open(pathconfig, "rb")
    config = decodeJson(file:read("*a"))
    healthpicker[0], healthpicker[1], healthpicker[2] = config.r, config.g, config.b
    slider[0] = config.distance
end

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('tags', function ()
        renderWindow[0] = not renderWindow[0]
    end)
    while true do
        wait(0)
        memory.setint8(sampGetServerSettingsPtr() + 56, 0)
        if config.showAfk then
            if afks == 0 then
                afkpng = afk0png
                rot1, rot2 = 8, 7
                afks = 1
                wait(500)
            elseif afks == 1 then
                afkpng = afk1png
                rot1, rot2 = 8, 7
                afks = 2
                wait(500)
            else
                afkpng = afk0png
                rot1, rot2 = 8, 7
                afks = 0
                wait(500)
            end
        end
    end
end
local backgroundDraw = imgui.OnFrame(
    function() return true end,
    function(self)
        self.HideCursor = true
        imgui.PushFont(nunitoFont)
        local dl = imgui.GetBackgroundDrawList()
        for k, v in pairs(getAllChars()) do
            if v ~= 1 then
                local res, id = sampGetPlayerIdByCharHandle(v)
                if isCharOnScreen(v) and wallPlayer(v) and not sampIsPlayerNpc(id) and res and sampIsPlayerConnected(id) then
                    local x, y, z = getNameTagPosForText(v)
                    local pos = imgui.ImVec2(convert3DCoordsToScreen(x, y, z))
                    local nick = sampGetPlayerNickname(id)
                    local sizey = 14
                    local armor = sampGetPlayerArmor(id)
                    local length = config.showid and (imgui.CalcTextSize(nick .. '(' .. id .. ')').x) / 2 or (imgui.CalcTextSize(nick).x) / 2 - 2
                    
                    if config.background then
                        for dx = -1, 1 do
                            for dy = -1, 1 do
                                if dx ~= 0 or dy ~= 0 then
                                    dl:AddText(
                                        imgui.ImVec2(pos.x - length + dx, pos.y + (config.showHealth and 0 or 20) + dy), 
                                        0xFF000000,
                                        (config.showid and nick .. ' (' .. id .. ')' or nick)
                                    )
                                end
                            end
                        end
                    end
                    
                    local a, r, g, b = explode_argb(sampGetPlayerColor(id))
                    dl:AddText(
                        imgui.ImVec2(pos.x - length, pos.y + (config.showHealth and 0 or 20)), 
                        (config.isWhite and 0xFFffffff or imgui.GetColorU32Vec4(imgui.ImVec4(r/255, g/255, b/255, 1))),
                        (config.showid and nick .. ' (' .. id .. ')' or nick)
                    )
                    
                    local ix, iy = pos.x - 25, pos.y + 35
                    if config.showHealth then
                        dl:AddImage(imhandle, imgui.ImVec2(ix + 7, iy - 7), imgui.ImVec2(ix - 7, iy + 7))
                        
                        local healthTextPosX = ix + 10 
                        local healthTextPosY = iy - 8   
                        if config.background then
                            for dx = -1, 1 do
                                for dy = -1, 1 do
                                    if dx ~= 0 or dy ~= 0 then
                                        dl:AddText(
                                            imgui.ImVec2(healthTextPosX + dx, healthTextPosY + dy),
                                            0xFF000000,
                                            tostring(sampGetPlayerHealth(id)) 
                                        )
                                    end
                                end
                            end
                        end
                        
                        dl:AddText(
                            imgui.ImVec2(healthTextPosX, healthTextPosY),
                            imgui.GetColorU32Vec4(imgui.ImVec4(healthpicker[0], healthpicker[1], healthpicker[2], 1)),
                            tostring(sampGetPlayerHealth(id)) 
                        )
                    end
                    
                    if armor > 0 then
                        local cx, cy = pos.x + 15, pos.y + 35
                        dl:AddImage(armourpng, imgui.ImVec2(cx + 8, cy - 9), imgui.ImVec2(cx - 7, cy + 6))
                        
                        local armorTextPosX = cx + 10 
                        local armorTextPosY = cy - 8   
                        if config.background then
                            for dx = -1, 1 do
                                for dy = -1, 1 do
                                    if dx ~= 0 or dy ~= 0 then
                                        dl:AddText(
                                            imgui.ImVec2(armorTextPosX + dx, armorTextPosY + dy),
                                            0xFF000000,
                                            tostring(armor) 
                                        )
                                    end
                                end
                            end
                        end
                        
                        dl:AddText(
                            imgui.ImVec2(armorTextPosX, armorTextPosY),
                            imgui.GetColorU32Vec4(imgui.ImVec4(healthpicker[0], healthpicker[1], healthpicker[2], 1)),
                            tostring(armor) 
                        )
                    end
                    
                    local cx, cy = pos.x + length + 15, pos.y + 7 + (config.showHealth and 0 or 20)
if sampIsPlayerPaused(id) and config.showAfk then
    lua_thread.create(function ()
        local offsetX = -7.0   
        local offsetY = -4.5   
        local scaleX = 1.80
        local scaleY = 1.05  

        dl:AddImage(
            afkpng, 
            imgui.ImVec2(cx - rot1 * scaleX - offsetX, cy - 9 * scaleY - offsetY), 
            imgui.ImVec2(cx + rot2 * scaleX - offsetX, cy + 6 * scaleY - offsetY)
        )
    end)
end

                end
            end
        end
        imgui.PopFont()
    end
)

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 300, 0
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        if imgui.Begin('NameTags+', renderWindow, imgui.WindowFlags.NoResize) then
            if imgui.RadioButtonBool('  Outline', config.background) then
                config.background = not config.background
            end
            imgui.SameLine()
            if imgui.RadioButtonBool('Show ID', config.showid) then
                config.showid = not config.showid
            end
            imgui.SameLine()
            if imgui.RadioButtonBool('Show AFK', config.showAfk) then
                config.showAfk = not config.showAfk
            end
            if imgui.RadioButtonBool('  White Names', config.isWhite) then
                config.isWhite = not config.isWhite
            end
            imgui.SameLine()
            if imgui.RadioButtonBool('Show HP', config.showHealth) then
                config.showHealth = not config.showHealth
            end
            rgba = imgui.ColorEdit4('  Color HP', healthpicker)
            if imgui.SliderInt('  Distance', slider, 0, memory.getfloat(sampGetServerSettingsPtr() + 39)) then
                config.distance = slider[0]
            end
            if imgui.Button('Save Config') then
                local cfg = {
                    background = config.background,
                    isWhite = config.isWhite,
                    distance = slider[0],
                    showid = config.showid,
                    showHealth = config.showHealth,
                    showAfk = config.showAfk,
                    r = healthpicker[0],
                    g = healthpicker[1],
                    b = healthpicker[2]
                }
                local encodedconfig = encodeJson(cfg)
                local file = io.open(pathconfig, "w")
                file:write(encodedconfig) 
                file:flush()
                file:close()
            end
            imgui.SameLine(105)
            if imgui.Button('Reset')
               local dist = memory.getfloat(sampGetServerSettingsPtr() + 39)
                 slider[0] = dist
                config.distance = dist
            end
            imgui.Text('Author: DuskBane')
            if imgui.IsItemClicked() then os.execute('explorer https://github.com/duskbane') end
            imgui.Text('Made for Visuals+')
            if imgui.IsItemClicked() then os.execute('explorer https://youtu.be/8bU_tI3SKmA?si=ZMusE3dsl76BGFO-') end
            imgui.PushFont(nunitoFont)
            imgui.PopFont()
            imgui.End()
        end
    end
) 

function wallPlayer(handle)
    local camX, camY, camZ = getActiveCameraCoordinates()
    local x, y, z = getCharCoordinates(handle)
    if isLineOfSightClear(camX, camY, camZ, x, y, z, true, false, false, true, false) and getDistanceBetweenCoords3d(camX, camY, camZ, x, y, z) <= config.distance then
        return true
    else
        return false
    end
end

function explode_argb(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
end
 

function getNameTagPosForText(ped)
    local localPlayerPos = vector3d(getActiveCameraCoordinates())
    local pPlayerPos = vector3d(getBodyPartCoordinates(8, ped))
    return pPlayerPos.x, pPlayerPos.y, pPlayerPos.z + 0.21 + ((getDistanceBetweenCoords3d(localPlayerPos.x, localPlayerPos.y, localPlayerPos.z, pPlayerPos.x, pPlayerPos.y, pPlayerPos.z) * 0.045))
end


local getBonePosition = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)
function getBodyPartCoordinates(id, handle)
    local pedptr = getCharPointer(handle)
    local vec = ffi.new("float[3]")
    getBonePosition(ffi.cast("void*", pedptr), vec, id, true)
    return vec[0], vec[1], vec[2]
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    nunitoFont = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory().."\\resources\\visualtags\\nunito.ttf", 18, nil, glyph_ranges)
    if doesFileExist(getWorkingDirectory()..'\\resources\\visualtags\\heart.png') and doesFileExist(getWorkingDirectory()..'\\resources\\visualtags\\armour.png') and doesFileExist(getWorkingDirectory()..'\\resources\\visualtags\\afk1.png') and doesFileExist(getWorkingDirectory()..'\\resources\\visualtags\\afk0.png') and doesFileExist(getWorkingDirectory()..'\\resources\\visualtags\\afk1.png') then
        imhandle = imgui.CreateTextureFromFile(getWorkingDirectory() .. '\\resources\\visualtags\\heart.png') 
        armourpng = imgui.CreateTextureFromFile(getWorkingDirectory()..'\\resources\\visualtags\\armour.png')
        afkpng = imgui.CreateTextureFromFile(getWorkingDirectory()..'\\resources\\visualtags\\afk1.png')
        afk0png = imgui.CreateTextureFromFile(getWorkingDirectory()..'\\resources\\visualtags\\afk0.png')
        afk1png = imgui.CreateTextureFromFile(getWorkingDirectory()..'\\resources\\visualtags\\afk1.png')
    end
    Theme()
end)
 
function Theme()
    imgui.SwitchContext()

    local style = imgui.GetStyle
    style().WindowPadding = imgui.ImVec2(8, 8)
    style().FramePadding = imgui.ImVec2(6, 4)
    style().ItemSpacing = imgui.ImVec2(6, 4)
    style().ItemInnerSpacing = imgui.ImVec2(4, 4)
    style().TouchExtraPadding = imgui.ImVec2(0, 0)
    style().IndentSpacing = 20
    style().ScrollbarSize = 12
    style().GrabMinSize = 10

    style().WindowRounding = 8
    style().ChildRounding = 6
    style().FrameRounding = 6
    style().PopupRounding = 6
    style().ScrollbarRounding = 8
    style().GrabRounding = 6
    style().TabRounding = 6

    style().WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style().ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    style().SelectableTextAlign = imgui.ImVec2(0.5, 0.5)

    style().Colors[imgui.Col.Text] = imgui.ImVec4(1, 1, 1, 1)  
    style().Colors[imgui.Col.WindowBg] = imgui.ImVec4(0, 0, 0, 0.4) 
    style().Colors[imgui.Col.ChildBg] = imgui.ImVec4(0, 0, 0, 0.3)
    style().Colors[imgui.Col.PopupBg] = imgui.ImVec4(0, 0, 0, 0.4)
    style().Colors[imgui.Col.Border] = imgui.ImVec4(0.5, 0.4, 0.6, 0.5)

    style().Colors[imgui.Col.FrameBg] = imgui.ImVec4(0.1, 0.1, 0.1, 0.3)
    style().Colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.3, 0.2, 0.4, 0.4)
    style().Colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.4, 0.3, 0.5, 0.5)

    style().Colors[imgui.Col.TitleBg] = imgui.ImVec4(0.1, 0.1, 0.2, 0.5)
    style().Colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.2, 0.15, 0.3, 0.6)
    style().Colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0, 0, 0, 0.4)

    style().Colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0, 0, 0, 0.3)
    style().Colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.6, 0.5, 0.8, 0.6)
    style().Colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.7, 0.6, 0.9, 0.6)
    style().Colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.8, 0.7, 1.0, 0.6)

    style().Colors[imgui.Col.CheckMark] = imgui.ImVec4(0.9, 0.7, 1.0, 0.8)

    style().Colors[imgui.Col.Button] = imgui.ImVec4(0.5, 0.4, 0.7, 0.6)
    style().Colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.6, 0.5, 0.8, 0.6)
    style().Colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.7, 0.6, 0.9, 0.6)

    style().Colors[imgui.Col.Header] = imgui.ImVec4(0.4, 0.3, 0.6, 0.6)
    style().Colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.5, 0.4, 0.7, 0.6)
    style().Colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.6, 0.5, 0.8, 0.6)

    style().Colors[imgui.Col.Separator] = imgui.ImVec4(0.4, 0.3, 0.5, 0.5)
    style().Colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.6, 0.5, 0.8, 0.6)
    style().Colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.7, 0.6, 0.9, 0.6)

    style().Colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.7, 0.5, 0.9, 0.6)
    style().Colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.8, 0.6, 1.0, 0.6)

    style().Colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.5, 0.3, 0.7, 0.5)
end
