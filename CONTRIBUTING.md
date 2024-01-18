# STOP

If you just want to use the final product, this readme is not for you. This readme is related contributing to the project, not using it.

If you have questions, bugs, feature requests, or feedback, please [open an issue](https://github.com/BusyCityGuy/finite-state-machine-luau/issues)!

# Contributing

## Clone the repository with submodules:

This project uses TestEZ as a submodule for running tests. To install this submodule dependency while cloning the repo, run one of the two commands:

| Method | Command                                                                                       |
| ------ | --------------------------------------------------------------------------------------------- |
| SSH    | `git clone --recurse-submodules git@github.com:BusyCityGuy/finite-state-machine-luau.git`     |
| HTTPS  | `git clone --recurse-submodules https://github.com/BusyCityGuy/finite-state-machine-luau.git` |

Or, if you already cloned it and need to install submodules afterward:
`git submodule update --init --recursive`

## Install tools

Various tools used by the project are installed with [Aftman](https://github.com/LPGhatguy/aftman), a toolchain manager.

1. Download and install Aftman from the [Aftman releases page](https://github.com/LPGhatguy/aftman/releases/latest) on your system.
1. Run `aftman install` in the repository directory. This installs tools from `aftman.toml` and adds them to your system environment path variable so you can use the tools in the command line.

### Tools in use

| Tool                      | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Rojo** for building     | This project uses [Rojo](<[https://rojo.space/](https://rojo.space/)>) to build from source files to a Roblox binary. You can either use the command line version installed by Aftman, or [install the VS Code extension](<[https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo](https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo)>) for a handy user interface for building and serving the project. See [Building the Project](#build-the-project) for details on using Rojo in this project.                                                |
| **Selene** for linting    | This project also uses [selene](<[https://kampfkarren.github.io/selene/roblox.html](https://kampfkarren.github.io/selene/roblox.html)>) for [linting](<[https://owasp.org/www-project-devsecops-guideline/latest/01b-Linting-Code](https://owasp.org/www-project-devsecops-guideline/latest/01b-Linting-Code)>). You can either use the command line version installed by Aftman, or [install the VS Code extension](<[https://marketplace.visualstudio.com/items?itemName=Kampfkarren.selene-vscode](https://marketplace.visualstudio.com/items?itemName=Kampfkarren.selene-vscode)>). |
| **StyLua** for formatting | This project's Luau code base is formatted with [StyLua](<[https://github.com/JohnnyMorganz/StyLua](https://github.com/JohnnyMorganz/StyLua)>). You can either use the command line version installed by Aftman, or [install the VS Code extension](<[https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.stylua](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.stylua)>)                                                                                                                                                                             |

## Build the project

Rojo builds from json files. This project includes two:

| File                   | Purpose                                                                                                                                                                                                                               |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `default.project.json` | The distributable consumer build in the form of a single ModuleScript and its children. This defines the structure when a consumer links this project into their `project.json` file.                                                 |
| `test.project.json`    | Useful for developing this project, because it defines an entire place file that can be opened and synced rather than just the ModuleScript. This is the one you should build and serve with Rojo during development of this project. |

To build for development, do either of the following:

| Method        | Instructions                                                                                                                                           |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| CLI           | `rojo build test.project.json -o StateMachine-Test.rbxl`                                                                                               |
| VSC Extension | Click Rojo on the status bar at the bottom, mouse over `test.project.json` in the pop-up menu, and click the Build icon on the right of the list item. |

## Sync file changes to studio

### Install the Rojo plugin for Roblox Studio plugin

To sync the codebase from your file system to Roblox Studio, you'll need the Rojo plugin for Roblox Studio. To install it, do either of the following:

| Method        | Instructions                                                                                            |
| ------------- | ------------------------------------------------------------------------------------------------------- |
| CLI           | `rojo plugin install`                                                                                   |
| VSC Extension | Click Rojo on the status bar at the bottom, and click `Install Roblox Studio Plugin` in the pop-up menu |

### Serve the project

Rojo makes your code base accessible to studio by starting a local server that your Roblox Studio plugin reads from. To start the server do either of the following:

| Method        | Instructions                                                                                 |
| ------------- | -------------------------------------------------------------------------------------------- |
| CLI           | `rojo serve test.project.json`                                                               |
| VSC Extension | Click Rojo on the status bar at the bottom, and click `test.project.json` in the pop-up menu |

Then, in the Roblox Studio Rojo plugin, click `Connect`.

### Run tests

This project uses [TestEZ](https://roblox.github.io/testez/) to ensure the state machine works as intended. To run tests in the project, open the test place file [built in the above step](#build-the-project) in Roblox Studio and run the file. The output widget will show the test results.
