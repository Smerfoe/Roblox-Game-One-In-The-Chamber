-- Init: starts every server service in ServerScriptService.Services.
-- Each service is a ModuleScript that may expose a Start() function.

for _, module in script.Parent.Services:GetChildren() do
	if module:IsA("ModuleScript") then
		local service = require(module)
		if type(service.Start) == "function" then
			service.Start()
		end
	end
end
