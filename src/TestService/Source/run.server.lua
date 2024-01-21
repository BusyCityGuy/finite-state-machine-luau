local TestService = game:GetService("TestService")

local TestEZ = require(TestService.Dependencies.TestEZ)

TestEZ.TestBootstrap:run({ TestService.Source.Tests })
