--[[
	On Unix-like systems, shell scripts can be run directly.
	On Windows, shell scripts need to be run by calling a shell executable, such as Git Bash.
	This script assumes the Windows machine has a shell runner installed and available in the PATH.
		- For example, Git Bash can be installed and C:\Program Files\Git\bin added to the PATH
--]]

local process = require("@lune/process")

local function runShellScript(scriptPath: string, args: { string }): process.ExecResult
	local proc

	if process.os == "windows" then
		proc = process.exec("sh", { scriptPath, table.unpack(args) })
	else
		proc = process.exec(scriptPath, args)
	end

	return proc
end

return runShellScript
