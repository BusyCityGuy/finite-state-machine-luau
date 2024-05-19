--!strict

--[[
	Analyzes all the same paths that get analyzed in the CI pipeline.

	Since the parent folder is named `lune`, the `lune` cli will automatically look in this directory for scripts to run.

	Usage (from project directory):
		lune run analyze
--]]

local process = require("@lune/process")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local ANALYZE_PATHS: { { path: string, project: string?, sourceMap: string? } } = {
	{
		path = "src/StateMachine",
		project = "default.project.json",
		sourceMap = "stateMachineSourcemap.json",
	},
	{
		path = "src/TestService",
		project = "test.project.json",
		sourceMap = "testSourcemap.json",
	},
	{
		path = "lune",
		project = nil,
		sourceMap = nil,
	},
}

local NUM_EXPECTED_TASKS = #ANALYZE_PATHS

local numErrors = 0
local numTasksCompleted = 0
local mainThread = coroutine.running()

local function buildSourceMap(projectFilePath: string, sourceMapFilePath: string)
	local proc = process.spawn("./scripts/sourcemap.sh", { projectFilePath, sourceMapFilePath })
	print(proc.stdout)
	assert(proc.ok, proc.stderr)
end

local function analyzePath(path: string, sourceMap: string?)
	local proc
	if sourceMap then
		proc = process.spawn("./scripts/analyze.sh", { sourceMap, path })
	else
		proc = process.spawn("./scripts/analyze.sh", { path })
	end

	print(proc.stdout)
	assert(proc.ok, proc.stderr)
end

local function analyzeAllPaths()
	print(`Analyzing {NUM_EXPECTED_TASKS} paths:`)
	for _, path in ipairs(ANALYZE_PATHS) do
		task.spawn(function()
			local success, errorMessage: string? = pcall(function()
				if path.project and path.sourceMap then
					buildSourceMap(path.project, path.sourceMap)
				end
				analyzePath(path.path, path.sourceMap)
			end)

			if not success then
				stdio.ewrite(errorMessage :: string)
				numErrors += 1
			end

			numTasksCompleted += 1
			if numTasksCompleted == NUM_EXPECTED_TASKS then
				coroutine.resume(mainThread)
			end
		end)
	end

	if numTasksCompleted < NUM_EXPECTED_TASKS then
		coroutine.yield()
	end

	if numErrors > 0 then
		stdio.ewrite(`{numErrors} of {NUM_EXPECTED_TASKS} paths FAILED analysis\n`)
		process.exit(1)
	end

	stdio.write(`All ({NUM_EXPECTED_TASKS}) paths analyzed successfully\n`)
end

analyzeAllPaths()
