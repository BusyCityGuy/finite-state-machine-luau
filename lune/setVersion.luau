--!strict

--[[
	Updates hardcoded versions in the project files to the version specified in the first argument.

	Since the parent folder is named `lune`, the `lune` cli will automatically look in this directory for scripts to run.

	Usage (from project directory):
		lune run setVersion 0.0.0
--]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local version: string = process.args[1]

local function updateFile(filePath: string, pattern: string, replacement: string)
	local fileContents = fs.readFile(filePath)
	local foundVersion = fileContents:match(pattern)
	assert(foundVersion, `Could not find version in {filePath}`)

	local updatedContents = fileContents:gsub(pattern, replacement)
	fs.writeFile(filePath, updatedContents)
	print(`Updated {filePath} from {foundVersion} to {replacement:match(pattern)}`)
end

local replacementData = {
	{
		path = "README.md",
		pattern = "finite%-state%-machine@([0-9]+%.[0-9]+%.[0-9]+)",
		replacement = `finite-state-machine@{version}`,
	},
	{
		path = "wally.toml",
		pattern = 'version = "([0-9]+%.[0-9]+%.[0-9]+)"',
		replacement = `version = "{version}"`,
	},
}

for _, data in replacementData do
	updateFile(data.path, data.pattern, data.replacement)
end

process.exit(0)
