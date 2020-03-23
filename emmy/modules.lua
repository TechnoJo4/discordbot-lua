---@class argdef
---@field name string @name of the var injected at runtime
---@field type string @converter used for this argument
---@field greedy boolean @matches until it fails, result is a table
---@field optional boolean @optional, tries to match but skips if it fails
local argdef = {}

---@class command
---@field name string @main alias of the command, shown in help
---@field aliases string[] @other aliases that can be used to run the command
---@field func function @function of the command
---@field args argdef[] @arguments that will be matched
local command = {}

---@class module
---@field name string
---@field emoji string
---@field commands command[]
local module = {}