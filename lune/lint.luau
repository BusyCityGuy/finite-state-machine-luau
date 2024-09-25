--!strict

--[[
	Lints all the same paths that get linted in the CI pipeline.

	Since the parent folder is named `lune`, the `lune` cli will automatically look in this directory for scripts to run.

	Usage (from project directory):
		lune run lint
--]]

local Path = require("Utils/Path")
local process = require("@lune/process")
local runShellScript = require("Utils/runShellScript")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local LINT_PATHS = {
	Path.join("src", "StateQ"),
	Path.join("src", "TestService"),
	"lune",
}

local NUM_EXPECTED_TASKS = #LINT_PATHS

local numErrors = 0
local numTasksCompleted = 0
local mainThread = coroutine.running()

local function lintPath(path: string)
	local lintScriptPath = Path.join("scripts", "lint.sh")
	local proc = runShellScript(lintScriptPath, { path })

	print(proc.stdout)
	if not proc.ok then
		stdio.ewrite(tostring(proc.stderr))
		numErrors += 1
	end

	numTasksCompleted += 1
	if numTasksCompleted == NUM_EXPECTED_TASKS then
		coroutine.resume(mainThread)
	end
end

local function lintAllPaths()
	print(`Linting {NUM_EXPECTED_TASKS} paths:`)
	for _, path in ipairs(LINT_PATHS) do
		task.spawn(lintPath, path)
	end

	if numTasksCompleted < NUM_EXPECTED_TASKS then
		coroutine.yield()
	end

	if numErrors > 0 then
		stdio.ewrite(`{numErrors} of {NUM_EXPECTED_TASKS} paths FAILED linting\n`)
		process.exit(1)
	end

	stdio.write(`All ({NUM_EXPECTED_TASKS}) paths linted successfully\n`)
end

lintAllPaths()
