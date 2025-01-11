--[[
    Input Library Usage Example
    Shows how to integrate and use the advanced input library
]]

local InputLib = require("input_lib")

-- Create an input field for chat with configuration
local chatInput = InputLib.create({
    maxLength = 1024,             -- Maximum text length
    minCursorPosition = 0,        -- Minimum cursor position (for protected prefixes)
    protectedPrefix = "/",        -- Optional protected prefix that can't be deleted
    
    -- Callback when text changes
    onChange = function(newText)
        -- Handle text changes
        print("Text changed to: " .. newText)
    end,
    
    -- Callback when Enter is pressed
    onEnter = function(finalText)
        -- Handle submitted text
        print("Text submitted: " .. finalText)
    end,
    
    -- Callback when Escape is pressed
    onEscape = function()
        -- Handle escape
        print("Input cancelled")
    end
})

-- Example: Basic chat implementation using the input library
local ChatExample = {
    active = false,
    font = nil
}

-- Initialize
function ChatExample:init()
    -- Create font for drawing
    self.font = draw.CreateFont("Verdana", 16, 800)
    
    -- Register necessary callbacks
    callbacks.Register("CreateMove", "chat_input", function(cmd)
        self:handleInput(cmd)
    end)
    
    callbacks.Register("Draw", "chat_draw", function()
        self:draw()
    end)
end

-- Handle input
function ChatExample:handleInput(cmd)
    -- Check if chat should be opened
    if input.IsButtonPressed(KEY_Y) and not self.active then
        -- Open chat
        self.active = true
        chatInput:setText("")  -- Clear input
        return
    end
    
    -- If chat is active, handle input
    if self.active then
        -- Block game input
        cmd.forwardmove = 0
        cmd.sidemove = 0
        cmd.buttons = 0
        
        -- Update input state
        chatInput:update()
    end
end

-- Draw chat
function ChatExample:draw()
    if not self.active then return end
    
    -- Draw background
    draw.Color(0, 0, 0, 127)
    draw.FilledRect(10, 500, 400, 530)
    
    -- Draw text
    draw.SetFont(self.font)
    draw.Color(255, 255, 255, 255)
    
    local text = chatInput:getText()
    local cursorPos = chatInput:getCursorPosition()
    
    -- Draw input text
    draw.Text(20, 507, text)
    
    -- Draw cursor
    if math.floor(globals.RealTime() * 2) % 2 == 0 then
        local beforeCursor = text:sub(1, cursorPos)
        local cursorX = 20 + draw.GetTextSize(beforeCursor)
        draw.Text(cursorX, 507, "|")
    end
    
    -- Draw selection if any
    local selStart, selEnd = chatInput:getSelection()
    if selStart and selEnd then
        local beforeSel = text:sub(1, selStart)
        local selText = text:sub(selStart + 1, selEnd)
        local selX = 20 + draw.GetTextSize(beforeSel)
        local selWidth = draw.GetTextSize(selText)
        
        -- Draw selection background
        draw.Color(50, 100, 150, 150)
        draw.FilledRect(selX, 505, selX + selWidth, 525)
        
        -- Redraw selected text
        draw.Color(255, 255, 255, 255)
        draw.Text(selX, 507, selText)
    end
end

-- Initialize the example
ChatExample:init()

--[[
Features demonstrated:
- Text input with cursor
- Selection
- Copy/paste
- Undo/redo
- Protected prefix
- Word navigation
- History
- Caps lock support
- UTF-8 support
]]
