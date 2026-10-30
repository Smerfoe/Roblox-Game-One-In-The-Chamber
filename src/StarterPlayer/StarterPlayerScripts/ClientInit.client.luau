-- ClientInit: starts every client controller in StarterPlayerScripts.Controllers.

for _, module in script.Parent:WaitForChild("Controllers"):GetChildren() do
	if module:IsA("ModuleScript") then
		local controller = require(module)
		if type(controller.Start) == "function" then
			controller.Start()
		end
	end
end
