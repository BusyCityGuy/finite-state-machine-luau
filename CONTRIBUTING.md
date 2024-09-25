# Contributing

## STOP

If you just want to use the final product, this readme is not for you. This readme is related contributing to the project, not using it.

If you have questions, bugs, feature requests, or feedback, please [open an issue](https://github.com/BusyCityGuy/finite-state-machine-luau/issues)!

## Clone the repository

This project does _not_ use submodules, so it can be cloned with either of the following commands:

| Method | Command                                                                  |
| ------ | ------------------------------------------------------------------------ |
| SSH    | `git clone git@github.com:BusyCityGuy/finite-state-machine-luau.git`     |
| HTTPS  | `git clone https://github.com/BusyCityGuy/finite-state-machine-luau.git` |

## Install tools

Various tools used by the project are installed with [Rokit](https://github.com/rojo-rbx/rokit), a toolchain manager.

1. Download and install Rokit by following the instructions on the [Rokit readme](https://github.com/rojo-rbx/rokit?tab=readme-ov-file#installation).
1. Run the following command in the repository directory:

```bash
rokit install
```

This installs tools from `rokit.toml` and adds them to your system environment path variable so you can use the tools in the command line.

Additionally, if you're using VS Code it's recommended to install the following extensions:

- [johnnymorganz.luau-lsp](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp)
- [johnnymorganz.stylua](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.stylua)
- [kampfkarren.selene-vscode](https://marketplace.visualstudio.com/items?itemName=Kampfkarren.selene-vscode)
- [streetsidesoftware.code-spell-checker](https://marketplace.visualstudio.com/items?itemName=streetsidesoftware.code-spell-checker)
> [!TIP]
> You should be automatically prompted to install these plugins when opening the project in VS Code because they're listed in [extensions.json](.vscode/extensions.json)

> [!IMPORTANT]  
> If you use luau-lsp as a language server, be sure to disable other conflicting plugins you might have such as Roblox LSP by Nightrains.

### Tools in use

The following tools are installed by Rokit:

| Tool                                        | Description                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Rojo** for building                       | This project uses [Rojo](https://rojo.space/) to build from source files to a Roblox binary. You can either use the command line version installed by Rokit (recommended), or [install the VS Code extension](https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo) for a handy user interface for building and serving the project. See [Building the Project](#build-the-project) for details on using Rojo in this project. |
| **Selene** for linting                      | This project also uses [selene](https://kampfkarren.github.io/selene/roblox.html) for [linting](https://owasp.org/www-project-devsecops-guideline/latest/01b-Linting-Code). You can either use the command line version installed by Rokit, or [install the VS Code extension](https://marketplace.visualstudio.com/items?itemName=Kampfkarren.selene-vscode) to have it constantly running in the background.                                  |
| **StyLua** for formatting                   | This project's Luau code base is formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua). You can either use the command line version installed by Rokit, or [install the VS Code extension](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.stylua)                                                                                                                                                                 |
| **Luau LSP** for analysis & language server | This project uses [Luau Language Server](https://github.com/JohnnyMorganz/luau-lsp) to run analysis on luau code as a ci step. While the tool is also a standalone language server, the recommended flow is to also [install the VS Code extension](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp) to have it constantly running in the background.                                                                 |
| **Wally** for package management            | This project uses [Wally](https://wally.run/) to fetch open source dependency packages. See [Installing Packages](#install-packages) for instructions on using this command line tool.                                                                                                                                                                                                                                                          |
| **Lune** for running tests from cli         | This project uses [Lune](https://lune-org.github.io/docs) to run tests from the command line. See [Run tests](#run-tests) for instructions on using this command line tool.                                                                                                                                                                                                                                                                     |

## Install packages

This project depends on packages to run and for testing. These packages are installed by Wally by running the following command:

```bash
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

## Set up Lune for your editor

Lune provides type definitions and documentation, but has to be configured for your editor. To do so, do the following steps (source: [Lune Editor Setup](https://lune-org.github.io/docs/getting-started/4-editor-setup))

Run the command:
```bash
lune setup
```

Then, modify your editor settings. For VS Code, open [`settings.json`](./.vscode/settings.json) and verify it contains the following:

```json
"luau-lsp.require.mode": "relativeToFile",
"luau-lsp.require.directoryAliases": {
 "@lune/": "~/.lune/.typedefs/x.y.z/"
}
```

An example [`settings.json`](./.vscode/settings.json) file is provided (see [`settings.json.example`](./.vscode/settings.json.example)), which also contains setup for the `luau-lsp` plugin to use [`test.project.json`](./test.project.json).

## Build the project

Rojo builds from json files that map files on your file system to locations in the roblox data model. This project includes two project.json files:

| File                   | Purpose                                                                                                                                                                                                                                                       |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`default.project.json`](./default.project.json) | The distributable consumer build in the form of a single ModuleScript and its children. This defines the structure when a consumer links this project into their `project.json` file.                                                 |
| [`test.project.json`](./test.project.json)       | Useful for developing this project, because it defines an entire place file that can be opened and synced rather than just the ModuleScript. This is the one you should build and serve with Rojo during development of this project. |

If you plan to [run tests](#run-tests) from CLI (recommended), the test runner script automatically builds before running tests. You don't need to build it yourself.

<details>
<summary>
If you're running tests in studio yourself (not recommended) instead of using the CLI, you can do an initial project build by expanding this section and doing either of the following:
</summary>

| Method        | Instructions                                                                                                                                           |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| CLI           | `rojo build test.project.json -o StateQ-Test.rbxl`                                                                                                     |
| VSC Extension | Click Rojo on the status bar at the bottom, mouse over `test.project.json` in the pop-up menu, and click the Build icon on the right of the list item. |
</details>

## Sync file changes to studio

> [!TIP]
> IF YOU ARE RUNNING TESTS USING THE COMMAND LINE INTERFACE (RECOMMENDED), THEN SKIP THIS SECTION! Go directly to [Run tests](#run-tests). You don't need to sync files to studio because you build the project before each test run.

<details>
<summary>
However, if you are manually running tests in studio (not recommended), you need to sync changes after the initial build. Expand this section and proceed with the following steps.
</summary>

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

## Testing

This project uses [Jest](https://jsdotlua.github.io/jest-lua/) to ensure the state machine works as intended. The recommended way to run tests is from the command line using [Lune](https://lune-org.github.io/docs), but you can also run them yourself in Roblox Studio.

### Flip required FFlag

THIS SECTION IS ONLY REQUIRED IF YOU ARE RUNNING TESTS IN ROBLOX STUDIO.

Jest depends on the `debug.loadmodule` function, which is an internal Roblox API that is normally unavailable in Roblox Studio.

If you're running tests in Lune from the CLI, you don't need to worry about this because the test runner contains a custom implementation of `debug.loadmodule`.

However, running tests in Roblox Studio requires flipping the `FFlagEnableLoadModule` flag to get access to this function. (Track the issue [here](https://github.com/jsdotlua/jest-lua/issues/3))

This instructions to flip this flag differ on Mac vs Windows.

* **For Mac users:** see [this issue](https://github.com/jsdotlua/jest-lua/issues/6).
* **For Windows users:** see [this devforum post](https://devforum.roblox.com/t/how-to-return-altenter-to-its-prior-functionality/997206)

You need to set the `FFlagEnableLoadModule` value to `true`. Be sure to restart Roblox Studio after flipping the flag.
</details>

### Run tests

| Method            | Instructions                                                                                                                                                                             |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CLI (recommended) | `lune run test`                                                                                                                                                                          |
| Roblox Studio     | Open the test place file `StateQ-Test.rbxl` [built in the above step](#build-the-project) in Roblox Studio and run the place (server only). The output widget will show the test results. |

### Continuous Integration (CI)

CI checks are set up to run on pull requests. These checks must pass before merging, including:

1. `lint` with selene
1. `format check` with StyLua
1. `analyze` with luau-lsp
1. `test` with jest running in Lune

#### Running CI Locally

To run the same CI checks locally that would run on GitHub, a number of Lune scripts are provided.

From the project directory, you can run the following:

> lune run ci

This will run all the same checks that would run on GitHub.

Alternatively, you can run individual steps yourself:

> lune run lint

> lune run formatCheck

> lune run analyze

> lune run test

There is an additional script available to fix formatting with StyLua, that does not run on GitHub:

> lune run formatFix
