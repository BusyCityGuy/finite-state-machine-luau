local TestService = game:GetService("TestService")

local TestEZ = require(script.Parent.TestEZ)

TestEZ.TestBootstrap:run({ TestService.Source.Tests })
