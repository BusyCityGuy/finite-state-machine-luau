--!strict

--[[
	Builds the release packages of the finite state machine. Used by CI to build the release packages for uploading to various targets.

	Since the parent folder is named `lune`, the `lune` cli will automatically look in this directory for scripts to run.

	Usage (from project directory):
		lune run build 0-0-0

	Where 0-0-0 is the version of the release.
	This creates a build folder in the root directory with a subdirectory for each build target. For example,
		- build
			- rbxm
				StateQ-0-0-0.rbxm
			- wally
				stateq-0-0-0
			- zip
				StateQ-0-0-0.zip

	You can also build without appending the version number if you want to test locally without putting a dummy version number in.
		lune run build
	This produces a structure like the following
		- build
			- rbxm
				StateQ.rbxm
			- wally
				stateq
			- zip
				StateQ.zip
--]]

local Path = require("Utils/Path")
local fs = require("@lune/fs")
local process = require("@lune/process")

local version = process.args[1]
assert(version == nil or version:match("^%d+%-%d+%-%d+$"), `Invalid version format. Expected "x-y-z", got "{version}"`)
local suffix = if version then `-{version}` else ""
local fileName = `StateQ{suffix}`
local buildFolder = "build"

local function ensurePath(...: string)
	local path = Path.join(...)
	if not fs.isDir(path) then
		fs.writeDir(path)
	end
	return path
end

local build_targets = {
	{
		description = "rbxm",
		command = "rojo",
		args = {
			"build",
			"default.project.json",
			"--output",
			`{Path.join(ensurePath(buildFolder, "rbxm"), `{fileName}.rbxm`)}`,
		},
	},
	{
		description = "Wally package",
		command = "wally",
		args = {
			"package",
			"--output",
			`{Path.join(ensurePath(buildFolder, "wally"), fileName:lower())}`,
		},
	},
	{
		description = "zip",
		command = "zip",
		args = {
			"-r",
			`{Path.join(ensurePath(buildFolder, "zip"), fileName)}.zip`,
			"src/StateQ",
			"default.project.json",
			"Packages",
			"README.md",
			"LICENSE.md",
		},
	},
}

for _, buildTarget in build_targets do
	print(`Building {buildTarget.description}...`)
	print(buildTarget.command, table.concat(buildTarget.args, " "))
	local proc = process.spawn(buildTarget.command, buildTarget.args)
	print(proc.stdout)
	assert(proc.ok, proc.stderr)
end

process.exit(0)
