local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

-- DEPENDENTS: [Jest]
local DateTime = require("Context/DateTime")
local Debug = require("Context/Debug")
local Runtime = require("Utils/Runtime")

-- DEPENDENTS: [runTests.lua, Jest]
local ReducedInstance = require("Utils/ReducedInstance")

local stateMachinePath = "./StateMachine-Test.rbxl"

if not fs.isFile(stateMachinePath) then
	local proc = process.spawn("rojo", {"build", "test.project.json", "-o", stateMachinePath})
	if not proc.ok then
		error(`Failed to build state machine: {proc.stderr}`)
	end
end

local game = roblox.deserializePlace(fs.readFile(stateMachinePath))

-- DEPENDENTS: [Jest]
roblox.implementMethod("Instance", "WaitForChild", function(self, ...)
	return self:FindFirstChild(...)
end)

-- DEPENDENTS: [Jest]
roblox.implementMethod("Instance", "isA", function(self, className: string)
	return self:IsA(className)
end)

-- DEPENDENTS: [Jest]
roblox.implementProperty("RunService", "Heartbeat", function()
	return {
		Wait = function(self)
			local thread = coroutine.running()
			local conn
			conn = Runtime:Connect(function(dt)
				conn:Disconnect()
				coroutine.resume(thread, dt)
			end)
			return coroutine.yield()
		end,
		Connect = Runtime.Connect,
	}
end)

local requireModule

-- DEPENDENTS: [TestService/Source/run.server.lua]
local contextGame = setmetatable({
	GetService = function(self, serviceName: string)
		if serviceName == "ProcessService" then
			return {
				ExitAsync = function(self, code: number)
					process.exit(code)
				end
			}
		end
		return game:GetService(serviceName)
	end
}, {__index = game})

-- DEPENDENTS: [runTests.lua, Jest]
local function loadScript(script: roblox.Instance) : (((...any) -> ...any)?, string?)
	script = ReducedInstance.once(script)::roblox.Instance -- 🤫
	if not script:IsA("LuaSourceContainer") then
		return nil, "Attempt to load a non LuaSourceContainer"
	end
	local bytecodeSuccess, bytecode = pcall(luau.compile, (script::never).Source)
	if not bytecodeSuccess then
		return nil, bytecode
	end
	local callableFn = luau.load(bytecode, {
		debugName = script:GetFullName(),
		environment = setmetatable({
			game = contextGame,
			script = script,
			require = requireModule,
			tick = os.clock,
			task = task,
			DateTime = DateTime,
			debug = Debug,
		}, {__index = roblox})::any,
	})

	return callableFn
end

Debug._loader = loadScript

-- Luau
local MODULE_REGISTRY = {}

-- DEPENDENTS: [Jest]
function requireModule(moduleScript: roblox.Instance)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		error("Attempt to require a whole lot of nada")
	end
	local cached = MODULE_REGISTRY[moduleScript]
	if cached then
		return cached
	end
	local func, err = loadScript(moduleScript)
	if not func then
		error(err)
	end
	local result = func()
	MODULE_REGISTRY[moduleScript] = result
	return result
end

local func, err = loadScript(ReducedInstance.once(game:GetService("TestService").Source.run))
if not func then
	error(err)
end

func()