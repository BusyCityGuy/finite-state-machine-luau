local task = require("@lune/task")

local Runtime = {}
Runtime._running = false
Runtime._listeners = {}

function Runtime._loop()
	if Runtime._running then
		return
	end
	Runtime._running = true
	while #Runtime._listeners > 0 do
		local listeners = Runtime._listeners
		local dt = task.wait()
		for _, listener in listeners do
			if not listener.disconnected then
				listener.callback(dt)
			end
		end
		for i = #listeners, 1, -1 do
			if listeners[i].disconnected then
				table.remove(listeners, i)
			end
		end
	end
	Runtime._running = false
end
function Runtime.Connect(_, callback: (number) -> ())
	local listener = {
		callback = callback,
		disconnected = false,
	}
	table.insert(Runtime._listeners, listener)
	task.spawn(Runtime._loop)
	return {
		Connected = true,
		Disconnect = function(self)
			self.disconnected = true
			listener.disconnected = true
		end
	}
end

return Runtime