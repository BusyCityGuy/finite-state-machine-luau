--!strict

--[[
	Lune script to run tests on a given project.json file. By default, it uses `test.project.json`, but can be passed a
	different file as an argument.

	Since the parent folder is named `lune`, the `lune` cli will automatically look in this directory for scripts to run.

	Usage (from project directory):
		lune run test [project.json]
--]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

-- DEPENDENTS: [Jest]
local DateTime = require("Context/DateTime")
local Debug = require("Context/Debug")
local Runtime = require("Utils/Runtime")

-- DEPENDENTS: [test.luau, Jest]
local ReducedInstance = require("Utils/ReducedInstance")

-- DEPENDENTS: [test.luau]
local Path = require("Utils/Path")

type RojoProject = {
	name: string,
	tree: any,
}

local DEFAULT_PROJECT_FILE_PATH = "test.project.json"

local function readRojoProject(filePath: string): RojoProject
	assert(
		fs.isFile(filePath),
		`Rojo project file {filePath} not found. Please create it or specify a different file as an argument.`
	)

	local success, result = pcall(serde.decode, "json" :: "json", fs.readFile(filePath))
	assert(success, `Failed to read Rojo project file {filePath}: {result}`)
	assert(result.name, "Rojo project name is required in the project file")

	return result :: RojoProject
end

local function buildProject(rojoProjectFilePath: string)
	local rojoProject = readRojoProject(rojoProjectFilePath)
	local builtProjectFilePath = `{rojoProject.name}.rbxl`
	local root = process.env.HOME or process.env.USERPROFILE
	local rojoPath = Path.join(root, ".rokit", "bin", "rojo")

	print(`Building project {rojoProjectFilePath} into {builtProjectFilePath} with Rojo...\n`)
	local proc = process.spawn(rojoPath, { "build", rojoProjectFilePath, "--output", builtProjectFilePath })
	assert(proc.ok, `Failed to build project [{builtProjectFilePath}]: {proc.stderr}`)

	print(`Deserializing {builtProjectFilePath}...`)
	local success, result = pcall(roblox.deserializePlace, fs.readFile(builtProjectFilePath))
	assert(success, `Failed to deserialize built project [{builtProjectFilePath}]: {result}`)

	return result
end

local function implementRobloxMethods()
	-- DEPENDENTS: [Jest]
	roblox.implementMethod("Instance", "WaitForChild", function(self, ...)
		local child = self:FindFirstChild(...)
		local childName = select(1, { ... })
		assert(
			child,
			`WaitForChild is not implemented in Lune, so FindFirstChild was substituted but {self:GetFullName()} does not contain child {childName} at the time of calling.`
		)
		return child
	end)

	-- DEPENDENTS: [Jest]
	roblox.implementMethod("Instance", "isA", function(self, className: string)
		return self:IsA(className)
	end)

	-- DEPENDENTS: [Jest]
	roblox.implementProperty("RunService", "Heartbeat", function()
		return {
			Wait = function(_self)
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
end

local rojoProjectFilePath = process.args[1] or DEFAULT_PROJECT_FILE_PATH
local game = buildProject(rojoProjectFilePath)
implementRobloxMethods()

-- Declaring because it's needed by `loadScript`, but `loadScript` is also needed in `requireModule`. Defined later.
local requireModule

-- DEPENDENTS: [TestService/Source/run.server.luau]
-- ProcessService isn't implemented in Lune, so this creates a workable implementation of it by mapping it to process.exit
local gameWithContext = setmetatable({
	GetService = function(_self, serviceName: string)
		if serviceName == "ProcessService" then
			return {
				ExitAsync = function(_self, code: number)
					process.exit(code)
				end,
			} :: any
		end

		return game:GetService(serviceName)
	end,
}, { __index = game })

-- DEPENDENTS: [test.luau, Jest]
local function loadScript(script: roblox.Instance): (((...any) -> ...any)?, string?)
	script = ReducedInstance.once(script)
	if not script:IsA("LuaSourceContainer") then
		return nil, "Attempt to load a non LuaSourceContainer"
	end

	local bytecodeSuccess, bytecode = pcall(luau.compile, (script :: any).Source)
	if not bytecodeSuccess then
		return nil, bytecode
	end

	local callableFn = luau.load(bytecode, {
		debugName = script:GetFullName(),
		environment = setmetatable({
			game = gameWithContext,
			script = script,
			require = requireModule,
			tick = os.clock,
			task = task,
			DateTime = DateTime,
			debug = Debug,
		}, { __index = roblox }) :: any,
	})

	return callableFn
end

-- Override the unimplemented _loader function with the above implementation
Debug._loader = loadScript

-- Luau
local MODULE_REGISTRY = {}

-- DEPENDENTS: [Jest]
function requireModule(moduleScript: roblox.Instance)
	assert(moduleScript and moduleScript:IsA("ModuleScript"), `Attempt to require a non ModuleScript {moduleScript}`)

	local cached = MODULE_REGISTRY[moduleScript]
	if cached then
		return cached
	end

	local func, err = loadScript(moduleScript)
	assert(func, err)

	local result = func()
	MODULE_REGISTRY[moduleScript] = result
	return result
end

-- Main
-- TODO: Flexibly run any script from a command line argument

print(`Starting main...\n`)
local TestService = game:GetService("TestService")
local Source = TestService:FindFirstChild("Source")
assert(Source, "game.TestService.Source not found")

local run = Source:FindFirstChild("run")
assert(run, "game.TestService.Source.run not found")

local func, err = loadScript(ReducedInstance.once(run))
assert(func, err)

print(`Running tests from game.TestService.Source.run...\n`)
func()
