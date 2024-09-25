--!strict

--[[
	Fixes the format for all the same paths that get fixed in the CI pipeline.
	This changes the files in place.
	To just check the format, run `lune run formatCheck` instead.

	Since the parent folder is named `lune`, the `lune` cli will automatically look in this directory for scripts to run.

	Usage (from project directory):
		lune run formatFix
--]]

local Path = require("Utils/Path")
local process = require("@lune/process")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local FORMAT_PATHS = {
	Path.join("src", "StateQ"),
	Path.join("src", "TestService"),
	"lune",
}

local NUM_EXPECTED_TASKS = #FORMAT_PATHS

local numErrors = 0
local numTasksCompleted = 0
local mainThread = coroutine.running()

local function fixFormatForPath(path: string)
	local root = process.env.HOME or process.env.USERPROFILE
	local styluaPath = Path.join(root, ".rokit", "bin", "stylua")
	local proc = process.spawn(styluaPath, { path })

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

local function formatFixAllPaths()
	print(`Fixing format for {NUM_EXPECTED_TASKS} paths:`)
	for _, path in ipairs(FORMAT_PATHS) do
		task.spawn(fixFormatForPath, path)
	end

	if numTasksCompleted < NUM_EXPECTED_TASKS then
		coroutine.yield()
	end

	if numErrors > 0 then
		stdio.ewrite(`{numErrors} of {NUM_EXPECTED_TASKS} paths FAILED to get format fixed\n`)
		process.exit(1)
	end

	stdio.write(`All ({NUM_EXPECTED_TASKS}) paths have fixed formats\n`)
end

formatFixAllPaths()
