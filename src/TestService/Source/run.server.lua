local TestService = game:GetService("TestService")

local Jest = require(TestService.Dependencies.Jest)
local runCLI = Jest.runCLI

-- Jest.TestBootstrap:run({ TestService.Source.Tests })

local processServiceExists, ProcessService = pcall(function()
	-- selene: allow(incorrect_standard_library_use)
	return game:GetService("ProcessService")
end)

local status, result = runCLI(TestService.Source.Tests, {
	verbose = false,
	ci = false,
}, { TestService.Source.Tests }):awaitStatus()

if status == "Rejected" then
	print(result)
end

if status == "Resolved" and result.results.numFailedTestSuites == 0 and result.results.numFailedTests == 0 then
	if processServiceExists then
		ProcessService:ExitAsync(0)
	end
end

if processServiceExists then
	ProcessService:ExitAsync(1)
end

return nil
