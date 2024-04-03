# STOP

If you just want to use the final product, this readme is not for you. This readme is related contributing to the project, not using it.

If you have questions, bugs, feature requests, or feedback, please [open an issue](https://github.com/BusyCityGuy/finite-state-machine-luau/issues)!

# Contributing

## Clone the repository

This project does _not_ use submodules, so it can be cloned with either of the following commands:

| Method | Command                                                                  |
| ------ | ------------------------------------------------------------------------ |
| SSH    | `git clone git@github.com:BusyCityGuy/finite-state-machine-luau.git`     |
| HTTPS  | `git clone https://github.com/BusyCityGuy/finite-state-machine-luau.git` |

## Install tools

Various tools used by the project are installed with [Aftman](https://github.com/LPGhatguy/aftman), a toolchain manager.

1. Download and install Aftman from the [Aftman releases page](https://github.com/LPGhatguy/aftman/releases/latest) on your system.
1. Run `aftman install` in the repository directory. This installs tools from `aftman.toml` and adds them to your system environment path variable so you can use the tools in the command line.

### Tools in use

The following tools are installed by Aftman:

| Tool                                         | Description                                                                                                                                                                                                                                                                                                                                                                                                                         |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Rojo** for building                        | This project uses [Rojo](https://rojo.space/) to build from source files to a Roblox binary. You can either use the command line version installed by Aftman, or [install the VS Code extension](https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo) for a handy user interface for building and serving the project. See [Building the Project](#build-the-project) for details on using Rojo in this project. |
| **Selene** for linting                       | This project also uses [selene](https://kampfkarren.github.io/selene/roblox.html) for [linting](https://owasp.org/www-project-devsecops-guideline/latest/01b-Linting-Code).                                                                                                                                                                                                                                                         |
| **StyLua** for formatting                    | This project's Luau code base is formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua). You can either use the command line version installed by Aftman, or [install the VS Code extension](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.stylua)                                                                                                                                                    |
| **Wally** for package management             | This project uses [Wally](https://wally.run/) to fetch open source dependency packages. See [Installing Packages](#install-packages) for instructions on using this command line tool.                                                                                                                                                                                                                                              |
| **Run in Roblox** for running tests from cli | This project uses [Run in Roblox](https://github.com/rojo-rbx/run-in-roblox) to run tests from the command line. See [Run tests](#run-tests) for instructions on using this command line tool.                                                                                                                                                                                                                                      |

## Install packages

This project depends on packages to run and for testing. These packages are installed by Wally by running the following command:

```
wally install
```

This will create `Packages` and `DevPackages` folders in the top level of the directory that are referenced by the `*.project.json` files.

### Packages in use

The following package is installed as a production dependency:

| Package                         | Description                                                                                                                                                                                                                                                                     |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **t** for runtime type checking | This project uses [t](https://github.com/osyrisrblx/t) to check parameter types at runtime. This helps quickly catch incorrect usage errors by providing specific error messages about incorrect parameter types instead of cascading into a potentially confusing error later. |

The following packages are installed as dev dependencies:

| Package                           | Description                                                                                                                                                                                                                                            |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Jest** for testing              | This project uses [Jest](https://jsdotlua.github.io/jest-lua/) to run tests on the state machine project to ensure accuracy and catch bugs during development. See [Running Tests](#run-tests) for instructions on how to run these tests.             |
| **Freeze** for table manipulation | This project uses [Freeze](https://duckarmor.github.io/Freeze/) to simplify manipulation of tables to make tests more concise and easier to understand.                                                                                                |

## Build the project

Rojo builds from json files that map files on your file system to locations in the roblox data model. This project includes two project.json files:

| File                   | Purpose                                                                                                                                                                                                                               |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `default.project.json` | The distributable consumer build in the form of a single ModuleScript and its children. This defines the structure when a consumer links this project into their `project.json` file.                                                 |
| `test.project.json`    | Useful for developing this project, because it defines an entire place file that can be opened and synced rather than just the ModuleScript. This is the one you should build and serve with Rojo during development of this project. |

If you plan to [run tests](#run-tests) from CLI (recommended), it's recommended to also build from CLI and use the `--watch` flag to automatically build when source changes. This avoids having to run the build command before every test command.

```
rojo build test.project.json --watch -o StateMachine-Test.rbxl
```

If you're running tests in studio yourself instead of using the CLI, you can do an initial project build with either of the following:

| Method        | Instructions                                                                                                                                           |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| CLI           | `rojo build test.project.json -o StateMachine-Test.rbxl`                                                                                               |
| VSC Extension | Click Rojo on the status bar at the bottom, mouse over `test.project.json` in the pop-up menu, and click the Build icon on the right of the list item. |

## Sync file changes to studio
IF YOU ARE RUNNING TESTS USING THE COMMAND LINE INTERFACE (RECOMMENDED), THEN SKIP THIS SECTION! Go directly to [Run tests](#run-tests) You don't need to sync files to studio because you build the project before each test run.

However, if you are manually running tests in studio, you need to sync changes after the initial build. Proceed with the following steps.

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
This project uses [Jest](https://jsdotlua.github.io/jest-lua/) to ensure the state machine works as intended. The recommended way to run tests is from the command line using [Run in Roblox](https://github.com/rojo-rbx/run-in-roblox), but you can also run them yourself in Roblox Studio.

#### Flip required FFlag
Jest depends on an internal Roblox API that requires flipping the `FFlagEnableLoadModule` flag. (Track the issue [here](https://github.com/jsdotlua/jest-lua/issues/3))

This instructions to flip this flag differ on Mac vs Windows.
* **For Mac users:** see [this issue](https://github.com/jsdotlua/jest-lua/issues/6).
* **For Windows users:** see [this devforum post](https://devforum.roblox.com/t/how-to-return-altenter-to-its-prior-functionality/997206)

You need to set the `FFlagEnableLoadModule` value to `true`. Be sure to restart Roblox Studio after flipping the flag.

#### Run tests
| Method            | Instructions                                                                                                                                                                                    |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CLI (recommended) | `run-in-roblox --place .\StateMachine-Test.rbxl --script .\src\TestService\Source\run.server.lua`                                                                                               |
| Roblox Studio     | Open the test place file `StateMachine-Test.rbxl` [built in the above step](#build-the-project) in Roblox Studio and run the place (server only). The output widget will show the test results. |

