--!strict

--[[
	Builds the release version of the finite state machine as an rbxm file.

	Since the parent folder is named `lune`, the `lune` cli will automatically look in this directory for scripts to run.

	Usage (from project directory):
		lune run build
	This produces a file named `finite-state-machine.rbxm` in the project root.

	Optionally specify a suffix, used for appending the version to the build output:
		lune run build 1-0-0
	This produces a file named `finite-state-machine-1-0-0.rbxm` in the project root.
--]]

local process = require("@lune/process")

local version = process.args[1]
local suffix = if version then `-{version}` else ""
local file_name = `finite-state-machine{suffix}.rbxm`
local params = { "build", "default.project.json", `-o {file_name}` }

local proc = process.spawn("rojo", params)
print(proc.stdout)
assert(proc.ok, proc.stderr)

process.exit(0)
