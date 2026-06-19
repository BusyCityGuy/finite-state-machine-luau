# StateQ: A Finite State Machine (FSM) in Luau

An intuitive fully-typed Finite State Machine in [Luau](https://luau-lang.org/) that supports async transitions by queueing events, developed for use in Roblox experiences.

This project is licensed under the terms of the MIT license. See [LICENSE.md](https://github.com/busycityguy/finite-state-machine-luau/blob/main/LICENSE.md) for details.

## This project is a work in progress

Tests need to be written and the API may receive small changes while this project is being finalized for a first release.

# What's a finite state machine?

A Finite State Machine (FSM) provides a way to enforce specific logical flow among a set of States. Given an Event, the FSM responds by looking up the corresponding Transition for that Event in its current State. A Transition is a callback function that is invoked when an Event is given to the FSM, and it returns the next State for the FSM to move to.

The FSM enforces that Events can only be called when a Transition is defined for that Event in its current State
by erroring if an Event is called in an invalid state (a state with no Transition defined for that Event).

# Included features

The FSM provides 6 signals. Five fire during normal handling of an event, and `eventErrored` fires when queued event processing fails.
These signals, transition callbacks, and state changes are processed in the following order:

![SequenceDiagram](https://github.com/BusyCityGuy/finite-state-machine-luau/assets/55513323/9ace09e3-a16e-474b-83ca-aac91cd69492)

1. Fire `beforeEvent` signal
    - with arguments `eventName`, `beforeState`
1. Call `transition.beforeAsync()` (required, returns next state)
    - with the VarArgs from `:handle(eventName, transitionArgs...)`
1. Fire `leavingState` signal
    - with arguments `beforeState, afterState`
1. Update `_currentState` to next state
1. Fire `stateEntered` signal
    - with arguments `afterState, beforeState`
1. Call `transition.afterAsync()` (if specified)
    - with the VarArgs from `:handle(eventName, transitionArgs...)`
1. Fire `afterEvent` signal
    - with arguments `eventName, afterState, beforeState`
1. Fire `finished` signal if next state from `beforeAsync()` was `nil`
    - with argument `beforeState`

Transitions can be asynchronous, which is supported by queuing each Event submitted via :handle() and processing them in First-In-First-Out (FIFO) order. The next Event starts processing immediately after the previous Event's handler fires `afterEvent`.

The FSM can Finish if a Transition does not return a "next state" during an event marked as "canBeFinal".
In such a case, the FSM will fire a `finished` event and will error if any further Events are handled.
A `nil` state means the FSM has Finished.

# Example usage

A simple state machine diagram for a light switch may look like this, where

- States are represented as rectangles, and squares indicate the State can be Final
- Events are represented as capsules

![ExampleUsage](https://github.com/BusyCityGuy/finite-state-machine-luau/assets/55513323/3d5b2118-91ea-4427-ac2d-688fb0094d1f)

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateQ = require(ReplicatedStorage.Packages.StateQ)

local LightState = {
	On = "On",
	Off = "Off",
}

local Event = {
	SwitchOn = "SwitchOn",
	SwitchOff = "SwitchOff",
}

local light = StateQ.new(LightState.On, {
	[Event.SwitchOn] = {
		canBeFinal = true,
		from = {
			[LightState.Off] = { -- From state
				beforeAsync = function() -- Transition
					print("Light is transitioning to On")
					for i = 1, 100 do
						-- do some action to increase brightness of a light here
						task.wait()
					end
					return LightState.On -- To next state
				end,
				afterAsync = function()
					print("Light is now On")
				end,
			}
		},
	},
	[Event.SwitchOff] = {
		canBeFinal = true,
		from = {
			[LightState.On] = {
				beforeAsync = function()
					print("Light is transitioning to Off")
					return LightState.Off
				end,
			}
		},
	},
})

light:handle(Event.SwitchOff) -- prints "Light is transitioning to Off"
light:handle(Event.SwitchOn) -- prints "Light is transitioning to On", increases brightness over time, and then prints "Light is now On"
light:handle(Event.SwitchOn) -- errors asynchronously via `eventErrored` (illegal event for the current state); see Error handling below
```

# Error handling

Every call to `:handle()` enqueues the event for processing on a background thread and returns immediately. Failures fall into two categories depending on when they occur.

## Synchronous errors

These throw on the thread that called `:handle()` before the event is enqueued:

- `eventName` is not a string (type check)
- The machine was `destroy()`ed
- `eventName` is not defined on the machine

In normal usage with known event names, these are programmer errors and should be left to throw during development.

If you are passing dynamic or untrusted event names, you can catch them with `pcall`:

```luau
local success, errorMessage = pcall(function()
	machine:handle(someEventName)
end)
if not success then
	warn(errorMessage)
end
```

## Asynchronous errors

These occur later, on the queue thread, while the event is actually being processed. They cannot propagate back to the `:handle()` caller, so they are surfaced through the `eventErrored` signal instead:

- A transition callback (`beforeAsync` or `afterAsync`) throws
- The event is illegal for the machine's **current** state at processing time (even if `:handle()` already returned)
- An event is processed after the machine has finished
- A non-final event's transition returns `nil`
- A transition returns a value that fails the state type check

Listen for them when you want to log, recover, or assert in tests:

```luau
machine.eventErrored:Connect(function(message)
	warn(message)
end)
```

The `message` includes the machine name, the error details, and a stack trace showing both where the failure occurred and where `:handle()` was called (`Queued from:`).

If nothing is connected to `eventErrored`, the error is re-raised on a new thread so it still appears in the output rather than being silently dropped.

### Swallowing asynchronous errors

The default re-raise is suppressed if at least one connection to `eventErrored` exists.

So if you intentionally want to swallow processing errors, you could connect an empty function:

```luau
machine.eventErrored:Connect(function(_message) end)
```


# Detailed system flowchart

![Flowchart](https://github.com/BusyCityGuy/finite-state-machine-luau/assets/55513323/5b3a5c8f-fd42-4021-b3a8-6da1256644d8)

# Installation

## Rojo users

If your project is set up to build with Rojo, the preferred installation method is using [Wally](https://wally.run/). Add this to your `wally.toml` file:

```bash
> StateQ = "busycityguy/stateq@0.0.6"
```

If you're not using Wally, you can add this repository as a submodule of your project by running the following command:

```bash
> git submodule add <https://github.com/BusyCityGuy/finite-state-machine-luau> path/to/your/dependencies
```

If you want to avoid submodules too, you can download the `.zip` file from the [latest release](https://github.com/BusyCityGuy/finite-state-machine-luau/releases/latest) page.

## Non-Rojo users

If you aren't using Rojo, you can download the `.rbxm` file from the [latest release](https://github.com/BusyCityGuy/finite-state-machine-luau/releases/latest) page and drag it into Roblox Studio, placing the `Packages` folder in `ReplicatedStorage`.

# Feedback

If you have other questions, bugs, feature requests, or feedback, please [open an issue](https://github.com/BusyCityGuy/finite-state-machine-luau/issues)!

# Contributing

See the [Contributing readme](CONTRIBUTING.md).
