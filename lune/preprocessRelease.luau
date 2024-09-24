--!strict

--[[
	Updates hardcoded versions in the project files to the version specified in the first argument.
	Also updates hardcoded copyright years to the current year.
	Meant to be used by the release workflow to update the codebase when a release is made.

	Since the parent folder is named `lune`, the `lune` cli will automatically look in this directory for scripts to run.

	Usage (from project directory):
		lune run preprocessRelease 0.0.0
--]]

local DateTime = require("@lune/datetime")
local fs = require("@lune/fs")
local process = require("@lune/process")

local version: string = process.args[1]

local function updateFile(description: string, filePath: string, pattern: string, replacement: string)
	local fileContents = fs.readFile(filePath)
	local foundMatch = fileContents:match(pattern)
	assert(foundMatch, `Could not find match for {description} in {filePath}`)

	local updatedContents = fileContents:gsub(pattern, replacement)
	fs.writeFile(filePath, updatedContents)
	print(`Updated {description} in {filePath} from {foundMatch} to {replacement:match(pattern)}`)
end

-- If you add files to this list that you expect to be automatically updated, be sure to update .github/workflows/release.yml to include
-- the new file in the `paths` list of the `set_version` job. The workflow specifies a second source of truth on which files to commit as
-- a safeguard against accidentally automatically committing unexpected changes to main, which could happen if it just committed changes from all files.
local replacementData = {
	{
		description = "package version",
		paths = { "README.md" },
		pattern = "finite%-state%-machine@([0-9]+%.[0-9]+%.[0-9]+)",
		replacement = `finite-state-machine@{version}`,
	},
	{
		description = "package version",
		paths = { "wally.toml" },
		pattern = 'version = "([0-9]+%.[0-9]+%.[0-9]+)"',
		replacement = `version = "{version}"`,
	},
	{
		description = "package version",
		paths = { "src/StateMachine/init.luau" },
		pattern = "%-%- Version: ([0-9]+%.[0-9]+%.[0-9]+)",
		replacement = `-- Version: {version}`,
	},
	{
		description = "copyright year",
		paths = { "src/StateMachine/init.luau", "LICENSE.md" },
		pattern = "Copyright %(c%) (%d+) BusyCityGuy",
		replacement = `Copyright (c) {DateTime.now():toUniversalTime().year} BusyCityGuy`,
	},
}

for _, data in replacementData do
	for _, path in data.paths do
		updateFile(data.description, path, data.pattern, data.replacement)
	end
end

process.exit(0)
