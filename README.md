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

The FSM provides 5 signals that can be listened to during handling of an event.
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
light:handle(Event.SwitchOn) -- warns "Illegal event `SwitchOn` called during state `On`" with a stack trace
```

# Detailed system flowchart

![Flowchart](https://github.com/BusyCityGuy/finite-state-machine-luau/assets/55513323/5b3a5c8f-fd42-4021-b3a8-6da1256644d8)

# Installation

## Rojo users

If your project is set up to build with Rojo, the preferred installation method is using [Wally](https://wally.run/). Add this to your `wally.toml` file:
> StateQ = "busycityguy/stateq@0.0.0"

If you're not using Wally, you can add this repository as a submodule of your project by running the following command:

> git submodule add https://github.com/BusyCityGuy/finite-state-machine-luau path/to/your/dependencies

If you want to avoid submodules too, you can download the `.zip` file from the [latest release](<https://github.com/BusyCityGuy/latest>) page.

## Non-Rojo users

If you aren't using Rojo, you can download the `.rbxm` file from the [latest release](<https://github.com/BusyCityGuy/latest>) page and drag it into Roblox Studio.

# Feedback

If you have other questions, bugs, feature requests, or feedback, please [open an issue](https://github.com/BusyCityGuy/finite-state-machine-luau/issues)!

# Contributing

See the [Contributing readme](CONTRIBUTING.md).
