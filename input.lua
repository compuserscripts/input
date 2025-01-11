--[[
    Advanced Input Library
    Based on lmaochat input system
    
    Features:
    - UTF-8 support
    - Undo/redo functionality
    - Cut/copy/paste
    - Word navigation
    - Selection
    - Key repeat handling
    - Caps lock support
    - Input history
]]

local InputLib = {}

-- State management
local State = {
    text = "",
    cursorPosition = 0,
    selectionStart = nil,
    selectionEnd = nil,
    maxLength = 1024,  -- Default max length
    minCursorPosition = 0,  -- Can be changed for protected prefixes
    inputHistory = {},
    historyIndex = 0,
    clipboard = "",
    isLocked = false,
    lastKeyPressTime = 0,
    capsLockEnabled = false,
    lastShiftState = false
}

-- Constants
local BACKSPACE_DELAY = 0.5
local BACKSPACE_REPEAT_RATE = 0.03
local ARROW_KEY_DELAY = 0.5
local ARROW_REPEAT_RATE = 0.03
local CTRL_ARROW_DELAY = 0.1
local MAX_HISTORY = 50

-- Key States
local LastKeyState = {}
local BackspaceStartTime = 0

-- Key repeat control
local KeyRepeatState = {
    INITIAL_DELAY = 0.5,
    REPEAT_RATE = 0.05,
    pressStartTimes = {},
    lastRepeatTimes = {},
    isRepeating = {},
    enabled = true,
    LastPressedKey = nil,
    frameInitialized = false,
    lastFrameKeys = {},
    keyPressCount = {}
}

-- Undo/Redo system
local UndoStack = {
    undoStack = {},
    redoStack = {},
    maxSize = 100,
    lastSavedState = nil,
    currentWord = "",
    lastWord = "",
    isTyping = false,
    typingTimeout = 0.5,
    lastTypeTime = 0
}

-- Input mapping with shift characters
local InputMap = {
    -- Numbers
    [KEY_0] = {normal = "0", shift = ")"},
    [KEY_1] = {normal = "1", shift = "!"},
    [KEY_2] = {normal = "2", shift = "@"},
    [KEY_3] = {normal = "3", shift = "#"},
    [KEY_4] = {normal = "4", shift = "$"},
    [KEY_5] = {normal = "5", shift = "%"},
    [KEY_6] = {normal = "6", shift = "^"},
    [KEY_7] = {normal = "7", shift = "&"},
    [KEY_8] = {normal = "8", shift = "*"},
    [KEY_9] = {normal = "9", shift = "("},
    
    -- Letters
    [KEY_A] = {normal = "a", shift = "A"},
    [KEY_B] = {normal = "b", shift = "B"},
    [KEY_C] = {normal = "c", shift = "C"},
    [KEY_D] = {normal = "d", shift = "D"},
    [KEY_E] = {normal = "e", shift = "E"},
    [KEY_F] = {normal = "f", shift = "F"},
    [KEY_G] = {normal = "g", shift = "G"},
    [KEY_H] = {normal = "h", shift = "H"},
    [KEY_I] = {normal = "i", shift = "I"},
    [KEY_J] = {normal = "j", shift = "J"},
    [KEY_K] = {normal = "k", shift = "K"},
    [KEY_L] = {normal = "l", shift = "L"},
    [KEY_M] = {normal = "m", shift = "M"},
    [KEY_N] = {normal = "n", shift = "N"},
    [KEY_O] = {normal = "o", shift = "O"},
    [KEY_P] = {normal = "p", shift = "P"},
    [KEY_Q] = {normal = "q", shift = "Q"},
    [KEY_R] = {normal = "r", shift = "R"},
    [KEY_S] = {normal = "s", shift = "S"},
    [KEY_T] = {normal = "t", shift = "T"},
    [KEY_U] = {normal = "u", shift = "U"},
    [KEY_V] = {normal = "v", shift = "V"},
    [KEY_W] = {normal = "w", shift = "W"},
    [KEY_X] = {normal = "x", shift = "X"},
    [KEY_Y] = {normal = "y", shift = "Y"},
    [KEY_Z] = {normal = "z", shift = "Z"},
    
    -- Special characters
    [KEY_SPACE] = {normal = " ", shift = " "},
    [KEY_MINUS] = {normal = "-", shift = "_"},
    [KEY_EQUAL] = {normal = "=", shift = "+"},
    [KEY_LBRACKET] = {normal = "[", shift = "{"},
    [KEY_RBRACKET] = {normal = "]", shift = "}"},
    [KEY_BACKSLASH] = {normal = "\\", shift = "|"},
    [KEY_SEMICOLON] = {normal = ";", shift = ":"},
    [KEY_APOSTROPHE] = {normal = "'", shift = "\""},
    [KEY_COMMA] = {normal = ",", shift = "<"},
    [KEY_PERIOD] = {normal = ".", shift = ">"},
    [KEY_SLASH] = {normal = "/", shift = "?"},
    [KEY_BACKQUOTE] = {normal = "`", shift = "~"}
}

-- Initialize LastKeyState for all used keys
for key, _ in pairs(InputMap) do
    LastKeyState[key] = false
end
LastKeyState[KEY_ENTER] = false
LastKeyState[KEY_ESCAPE] = false
LastKeyState[KEY_BACKSPACE] = false
LastKeyState[KEY_CAPSLOCK] = false

-- Helper Functions
local function isWordBoundary(char)
    return char == " " or char == "\t" or char == "\n" or char == nil or
           char:match("[%p%c]") -- punctuation or control characters
end

local function getNextUTF8Char(text, pos)
    if pos > #text then return nil end
    local byte = text:byte(pos)
    local length = 1
    if byte >= 240 then length = 4
    elseif byte >= 224 then length = 3
    elseif byte >= 192 then length = 2 end
    return text:sub(pos, pos + length - 1)
end

local function getPrevUTF8Char(text, pos)
    if pos <= 1 then return nil end
    local byte = text:byte(pos - 1)
    if byte >= 128 and byte < 192 then
        if pos >= 4 and text:byte(pos - 4) >= 240 then return 4
        elseif pos >= 3 and text:byte(pos - 3) >= 224 then return 3
        elseif pos >= 2 and text:byte(pos - 2) >= 192 then return 2
        end
    end
    return 1
end

local function createStateSnapshot()
    return {
        text = State.text,
        cursorPos = State.cursorPosition,
        timestamp = globals.RealTime()
    }
end

local function resetAllKeyStates()
    KeyRepeatState.pressStartTimes = {}
    KeyRepeatState.lastRepeatTimes = {}
    KeyRepeatState.isRepeating = {}
    KeyRepeatState.LastPressedKey = nil
    for key in pairs(LastKeyState) do
        LastKeyState[key] = false
    end
end

local function resetKeyRepeatState(key)
    KeyRepeatState.pressStartTimes[key] = nil
    KeyRepeatState.lastRepeatTimes[key] = nil
    KeyRepeatState.isRepeating[key] = nil
    if KeyRepeatState.LastPressedKey == key then
        KeyRepeatState.LastPressedKey = nil
    end
end

local function handleCharacterInput()
    local currentWord = State.text:sub(1, State.cursorPosition):match("%S+$") or ""
    local currentTime = globals.RealTime()
    
    if not UndoStack.isTyping then
        UndoStack.isTyping = true
        UndoStack.currentWord = currentWord
        UndoStack.lastWord = currentWord
        UndoStack.lastTypeTime = currentTime
        table.insert(UndoStack.undoStack, createStateSnapshot())
        return
    end
    
    local lastChar = State.text:sub(-1)
    if isWordBoundary(lastChar) then
        if #UndoStack.currentWord > 0 then
            UndoStack.isTyping = false
            table.insert(UndoStack.undoStack, createStateSnapshot())
            UndoStack.isTyping = true
            UndoStack.currentWord = ""
            UndoStack.lastWord = ""
        end
    else
        UndoStack.currentWord = currentWord
        UndoStack.lastWord = currentWord
    end
    UndoStack.lastTypeTime = currentTime
end

local function addToHistory(text)
    if text == "" or text == State.inputHistory[1] then return end
    table.insert(State.inputHistory, 1, text)
    while #State.inputHistory > MAX_HISTORY do
        table.remove(State.inputHistory)
    end
    State.historyIndex = 0
end

-- Core Input Library Functions
function InputLib.create(config)
    local instance = setmetatable({}, {__index = InputLib})
    
    -- Initialize state with config
    instance.state = {
        text = "",
        cursorPosition = 0,
        selectionStart = nil,
        selectionEnd = nil,
        maxLength = config.maxLength or 1024,
        minCursorPosition = config.minCursorPosition or 0,
        protectedPrefix = config.protectedPrefix,
        inputHistory = {},
        historyIndex = 0,
        clipboard = "",
        onChange = config.onChange,
        onEnter = config.onEnter,
        onEscape = config.onEscape
    }
    
    return instance
end

function InputLib:setText(text)
    self.state.text = text
    self.state.cursorPosition = #text
    if self.state.onChange then
        self.state.onChange(text)
    end
end

function InputLib:getText()
    return self.state.text
end

function InputLib:getCursorPosition()
    return self.state.cursorPosition
end

function InputLib:getSelection()
    if not self.state.selectionStart or not self.state.selectionEnd then
        return nil
    end
    return math.min(self.state.selectionStart, self.state.selectionEnd),
           math.max(self.state.selectionStart, self.state.selectionEnd)
end

function InputLib:clearSelection()
    self.state.selectionStart = nil
    self.state.selectionEnd = nil
end

function InputLib:undo()
    if #UndoStack.undoStack > 1 then
        local currentState = createStateSnapshot()
        table.insert(UndoStack.redoStack, currentState)
        
        table.remove(UndoStack.undoStack)
        local prevState = UndoStack.undoStack[#UndoStack.undoStack]
        
        self.state.text = prevState.text
        self.state.cursorPosition = prevState.cursorPos
        UndoStack.lastSavedState = prevState
        
        UndoStack.isTyping = false
        UndoStack.currentWord = ""
        UndoStack.lastWord = ""
        
        if self.state.onChange then
            self.state.onChange(self.state.text)
        end
    end
end

function InputLib:redo()
    if #UndoStack.redoStack > 0 then
        local redoState = table.remove(UndoStack.redoStack)
        table.insert(UndoStack.undoStack, createStateSnapshot())
        
        self.state.text = redoState.text
        self.state.cursorPosition = redoState.cursorPos
        UndoStack.lastSavedState = redoState
        
        UndoStack.isTyping = false
        UndoStack.currentWord = ""
        
        if self.state.onChange then
            self.state.onChange(self.state.text)
        end
    end
end

function InputLib:update()
    local currentTime = globals.RealTime()
    local shiftPressed = input.IsButtonDown(KEY_LSHIFT) or input.IsButtonDown(KEY_RSHIFT)
    local ctrlPressed = input.IsButtonDown(KEY_LCONTROL) or input.IsButtonDown(KEY_RCONTROL)
    
    -- Handle Caps Lock
    if input.IsButtonPressed(KEY_CAPSLOCK) and not LastKeyState[KEY_CAPSLOCK] then
        State.capsLockEnabled = not State.capsLockEnabled
    end
    LastKeyState[KEY_CAPSLOCK] = input.IsButtonDown(KEY_CAPSLOCK)
    
    -- Handle control shortcuts first
    if ctrlPressed then
        -- Undo (Ctrl+Z)
        if input.IsButtonPressed(KEY_Z) and not LastKeyState[KEY_Z] then
            self:undo()
            return true
        end
        
        -- Redo (Ctrl+Y)
        if input.IsButtonPressed(KEY_Y) and not LastKeyState[KEY_Y] then
            self:redo()
            return true
        end
        
        -- Select All (Ctrl+A)
        if input.IsButtonPressed(KEY_A) and not LastKeyState[KEY_A] then
            self.state.selectionStart = self.state.minCursorPosition
            self.state.selectionEnd = #self.state.text
            self.state.cursorPosition = self.state.minCursorPosition
            return true
        end
        
        -- Cut (Ctrl+X)
        if input.IsButtonPressed(KEY_X) and not LastKeyState[KEY_X] then
            if self.state.selectionStart and self.state.selectionEnd then
                local start = math.max(self.state.minCursorPosition, 
                                     math.min(self.state.selectionStart, self.state.selectionEnd))
                local finish = math.max(self.state.selectionStart, self.state.selectionEnd)
                
                self.state.clipboard = self.state.text:sub(start + 1, finish)
                self.state.text = self.state.text:sub(1, start) ..
                                self.state.text:sub(finish + 1)
                self.state.cursorPosition = start
                self:clearSelection()
                
                if self.state.onChange then
                    self.state.onChange(self.state.text)
                end
                return true
            end
        end
        
        -- Copy (Ctrl+C)
        if input.IsButtonPressed(KEY_C) and not LastKeyState[KEY_C] then
            if self.state.selectionStart and self.state.selectionEnd then
                local start = math.max(self.state.minCursorPosition,
                                     math.min(self.state.selectionStart, self.state.selectionEnd))
                local finish = math.max(self.state.selectionStart, self.state.selectionEnd)
                self.state.clipboard = self.state.text:sub(start + 1, finish)
            end
            return true
        end
        
        -- Paste (Ctrl+V)
        if input.IsButtonPressed(KEY_V) and not LastKeyState[KEY_V] then
            if self.state.clipboard and self.state.clipboard ~= "" then
                if self.state.selectionStart and self.state.selectionEnd then
                    local start = math.max(self.state.minCursorPosition,
                                         math.min(self.state.selectionStart, self.state.selectionEnd))
                    local finish = math.max(self.state.selectionStart, self.state.selectionEnd)
                    
                    local before = self.state.text:sub(1, start)
                    local after = self.state.text:sub(finish + 1)
                    
                    if #before + #self.state.clipboard + #after <= self.state.maxLength then
                        self.state.text = before .. self.state.clipboard .. after
                        self.state.cursorPosition = start + #self.state.clipboard
                        self:clearSelection()
                        handleCharacterInput()
                    end
                else
                    local before = self.state.text:sub(1, self.state.cursorPosition)
                    local after = self.state.text:sub(self.state.cursorPosition + 1)
                    
                    if #before + #self.state.clipboard + #after <= self.state.maxLength then
                        self.state.text = before .. self.state.clipboard .. after
                        self.state.cursorPosition = self.state.cursorPosition + #self.state.clipboard
                        handleCharacterInput()
                    end
                end
                
                if self.state.onChange then
                    self.state.onChange(self.state.text)
                end
                return true
            end
        end
        
        -- Word navigation
        if input.IsButtonPressed(KEY_LEFT) and not LastKeyState[KEY_LEFT] and
            (currentTime - (self.lastCtrlArrowTime or 0) >= CTRL_ARROW_DELAY) then
            
            self.lastCtrlArrowTime = currentTime
            local pos = self.state.cursorPosition
            
            -- Skip whitespace before cursor
            while pos > self.state.minCursorPosition and self.state.text:sub(pos, pos):match("%s") do
                pos = pos - 1
            end
            
            -- Skip to start of current/previous word
            while pos > self.state.minCursorPosition and not self.state.text:sub(pos, pos):match("%s") do
                pos = pos - 1
            end
            
            -- Skip trailing whitespace
            while pos > self.state.minCursorPosition and self.state.text:sub(pos, pos):match("%s") do
                pos = pos - 1
            end
            
            self.state.cursorPosition = pos
            self:clearSelection()
            return true
            
        elseif input.IsButtonPressed(KEY_RIGHT) and not LastKeyState[KEY_RIGHT] and
            (currentTime - (self.lastCtrlArrowTime or 0) >= CTRL_ARROW_DELAY) then
            
            self.lastCtrlArrowTime = currentTime
            local pos = self.state.cursorPosition
            
            -- Skip whitespace after cursor
            while pos < #self.state.text and self.state.text:sub(pos + 1, pos + 1):match("%s") do
                pos = pos + 1
            end
            
            -- Skip to end of current/next word
            while pos < #self.state.text and not self.state.text:sub(pos + 1, pos + 1):match("%s") do
                pos = pos + 1
            end
            
            self.state.cursorPosition = pos
            self:clearSelection()
            return true
        end
    else
        -- Regular cursor movement
        if input.IsButtonDown(KEY_LEFT) then
            if not LastKeyState[KEY_LEFT] then
                self.state.cursorPosition = math.max(self.state.minCursorPosition, 
                                                   self.state.cursorPosition - 1)
                self.lastArrowPressTime = currentTime
                self.lastKeyPressTime = currentTime
            else
                local timeHeld = currentTime - self.lastArrowPressTime
                if timeHeld > ARROW_KEY_DELAY then
                    if currentTime - self.lastKeyPressTime >= ARROW_REPEAT_RATE then
                        self.state.cursorPosition = math.max(self.state.minCursorPosition, 
                                                           self.state.cursorPosition - 1)
                        self.lastKeyPressTime = currentTime
                    end
                end
            end
            self:clearSelection()
            return true
        elseif input.IsButtonDown(KEY_RIGHT) then
            if not LastKeyState[KEY_RIGHT] then
                self.state.cursorPosition = math.min(#self.state.text, 
                                                   self.state.cursorPosition + 1)
                self.lastArrowPressTime = currentTime
                self.lastKeyPressTime = currentTime
            else
                local timeHeld = currentTime - self.lastArrowPressTime
                if timeHeld > ARROW_KEY_DELAY then
                    if currentTime - self.lastKeyPressTime >= ARROW_REPEAT_RATE then
                        self.state.cursorPosition = math.min(#self.state.text, 
                                                           self.state.cursorPosition + 1)
                        self.lastKeyPressTime = currentTime
                    end
                end
            end
            self:clearSelection()
            return true
        end
    end
    
    -- Handle Enter/Return
    if input.IsButtonPressed(KEY_ENTER) and not LastKeyState[KEY_ENTER] then
        if self.state.text ~= "" then
            addToHistory(self.state.text)
        end
        if self.state.onEnter then
            self.state.onEnter(self.state.text)
        end
        return true
    end
    
    -- Handle Escape
    if input.IsButtonPressed(KEY_ESCAPE) and not LastKeyState[KEY_ESCAPE] then
        if self.state.onEscape then
            self.state.onEscape()
        end
        return true
    end
    
    -- Handle history navigation
    if input.IsButtonPressed(KEY_UP) and not LastKeyState[KEY_UP] then
        if self.state.historyIndex < #self.state.inputHistory then
            self.state.historyIndex = self.state.historyIndex + 1
            self.state.text = self.state.inputHistory[self.state.historyIndex]
            if self.state.protectedPrefix and not self.state.text:find("^" .. self.state.protectedPrefix) then
                self.state.text = self.state.protectedPrefix .. self.state.text
            end
            self.state.cursorPosition = #self.state.text
            if self.state.onChange then
                self.state.onChange(self.state.text)
            end
        end
        return true
    elseif input.IsButtonPressed(KEY_DOWN) and not LastKeyState[KEY_DOWN] then
        if self.state.historyIndex > 0 then
            self.state.historyIndex = self.state.historyIndex - 1
            if self.state.historyIndex == 0 then
                self.state.text = self.state.protectedPrefix or ""
            else
                self.state.text = self.state.inputHistory[self.state.historyIndex]
                if self.state.protectedPrefix and not self.state.text:find("^" .. self.state.protectedPrefix) then
                    self.state.text = self.state.protectedPrefix .. self.state.text
                end
            end
            self.state.cursorPosition = #self.state.text
            if self.state.onChange then
                self.state.onChange(self.state.text)
            end
        end
        return true
    end
    
    -- Handle regular character input
    for key, chars in pairs(InputMap) do
        if input.IsButtonDown(key) then
            local keyPressed = true
            if key ~= KeyRepeatState.LastPressedKey then
                resetAllKeyStates()
                KeyRepeatState.LastPressedKey = key
            end
            
            if not KeyRepeatState.frameInitialized then
                KeyRepeatState.lastFrameKeys = {}
                KeyRepeatState.frameInitialized = true
            end
            
            if not KeyRepeatState.keyPressCount[key] then
                KeyRepeatState.keyPressCount[key] = 0
            end
            
            local shouldAddChar = false
            local wasPressed = KeyRepeatState.lastFrameKeys[key]
            
            if not wasPressed then
                shouldAddChar = true
                KeyRepeatState.pressStartTimes[key] = currentTime
                KeyRepeatState.lastRepeatTimes[key] = currentTime
                KeyRepeatState.keyPressCount[key] = 1
            else
                local timeHeld = currentTime - KeyRepeatState.pressStartTimes[key]
                if timeHeld >= KeyRepeatState.INITIAL_DELAY then
                    local timeSinceLastRepeat = currentTime - KeyRepeatState.lastRepeatTimes[key]
                    if timeSinceLastRepeat >= KeyRepeatState.REPEAT_RATE then
                        shouldAddChar = true
                        KeyRepeatState.lastRepeatTimes[key] = currentTime
                    end
                end
            end
            
            KeyRepeatState.lastFrameKeys[key] = true
            
            if shouldAddChar then
                local nextChar
                if chars.normal:match("%a") then
                    local useUpperCase = (State.capsLockEnabled and not shiftPressed) or 
                                       (not State.capsLockEnabled and shiftPressed)
                    nextChar = useUpperCase and chars.shift or chars.normal
                else
                    nextChar = shiftPressed and chars.shift or chars.normal
                end
                
                if self.state.selectionStart and self.state.selectionEnd then
                    local start = math.max(self.state.minCursorPosition,
                                         math.min(self.state.selectionStart, self.state.selectionEnd))
                    local finish = math.max(self.state.selectionStart, self.state.selectionEnd)
                    
                    local before = self.state.text:sub(1, start)
                    local after = self.state.text:sub(finish + 1)
                    
                    if #before + #nextChar + #after <= self.state.maxLength then
                        self.state.text = before .. nextChar .. after
                        self.state.cursorPosition = start + #nextChar
                        self:clearSelection()
                        handleCharacterInput()
                        
                        if self.state.onChange then
                            self.state.onChange(self.state.text)
                        end
                    end
                else
                    local before = self.state.text:sub(1, self.state.cursorPosition)
                    local after = self.state.text:sub(self.state.cursorPosition + 1)
                    
                    if #before + #nextChar + #after <= self.state.maxLength then
                        self.state.text = before .. nextChar .. after
                        self.state.cursorPosition = self.state.cursorPosition + #nextChar
                        handleCharacterInput()
                        
                        if self.state.onChange then
                            self.state.onChange(self.state.text)
                        end
                    end
                end
            end
            break
        end
    end
    
    -- Handle backspace with protected prefix
    if input.IsButtonDown(KEY_BACKSPACE) then
        if self.state.selectionStart and self.state.selectionEnd then
            local start = math.max(self.state.minCursorPosition,
                                 math.min(self.state.selectionStart, self.state.selectionEnd))
            local finish = math.max(self.state.selectionStart, self.state.selectionEnd)
            
            if start >= self.state.minCursorPosition then
                self.state.text = self.state.text:sub(1, start) ..
                                self.state.text:sub(finish + 1)
                self.state.cursorPosition = start
                self:clearSelection()
                
                if self.state.onChange then
                    self.state.onChange(self.state.text)
                end
            end
        elseif self.state.cursorPosition > self.state.minCursorPosition then
            if not LastKeyState[KEY_BACKSPACE] then
                local before = self.state.text:sub(1, self.state.cursorPosition - 1)
                local after = self.state.text:sub(self.state.cursorPosition + 1)
                self.state.text = before .. after
                self.state.cursorPosition = self.state.cursorPosition - 1
                handleCharacterInput()
                
                if self.state.onChange then
                    self.state.onChange(self.state.text)
                end
                BackspaceStartTime = currentTime
            else
                local timeSinceStart = currentTime - BackspaceStartTime
                if timeSinceStart > BACKSPACE_DELAY then
                    if currentTime - self.lastKeyPressTime >= BACKSPACE_REPEAT_RATE then
                        local before = self.state.text:sub(1, self.state.cursorPosition - 1)
                        local after = self.state.text:sub(self.state.cursorPosition + 1)
                        self.state.text = before .. after
                        self.state.cursorPosition = self.state.cursorPosition - 1
                        handleCharacterInput()
                        
                        if self.state.onChange then
                            self.state.onChange(self.state.text)
                        end
                        self.lastKeyPressTime = currentTime
                    end
                end
            end
        end
        return true
    else
        LastKeyState[KEY_BACKSPACE] = false
        BackspaceStartTime = 0
    end
    
    -- Update key states
    for key in pairs(InputMap) do
        LastKeyState[key] = input.IsButtonDown(key)
    end
    LastKeyState[KEY_ENTER] = input.IsButtonDown(KEY_ENTER)
    LastKeyState[KEY_ESCAPE] = input.IsButtonDown(KEY_ESCAPE)
    
    return false
end

return InputLib
