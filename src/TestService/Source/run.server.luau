local TestService = game:GetService("TestService")

local Jest = require(TestService.Source.DevPackages.Jest)
local runCLI = Jest.runCLI

-- Jest.TestBootstrap:run({ TestService.Source.Tests })

print("Checking for ProcessService...")
local processServiceExists, ProcessService = pcall(function()
	-- selene: allow(incorrect_standard_library_use)
	return game:GetService("ProcessService")
end)
print(`ProcessService {processServiceExists and "exists" or "does not exist"}`)

print("Running jest tests cli...")
local status, result = runCLI(TestService.Source.Tests, {
	verbose = false,
	ci = false,
}, { TestService.Source.Tests }):awaitStatus()
print(`Jest tests completed with status {status}`)

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
