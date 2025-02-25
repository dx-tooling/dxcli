# DX CLI - Developer Experience CLI for Symfony Projects

DX CLI is a lightweight, extensible command-line interface designed to enhance the developer experience in software develpoment projects.
It provides a standardized way to create, share, and execute common development tasks across your team and projects.


## Features

- **Standardized Command Interface**: Consistent command structure across all your projects
- **Extensible Architecture**: Easily add custom commands specific to your project
- **Command Repository Support**: Install commands from external Git repositories
- **Global Command Access**: Run commands from anywhere in your project
- **Configuration File**: Automatically install commands from specified repositories
- **Self-updating**: Keep your DX CLI installation up to date


## Quick Installation

While in the root folder of your codebase, run:

```bash
curl -fsSL https://raw.githubusercontent.com/Enterprise-Tooling-for-Symfony/dxcli/refs/heads/main/dxify.sh | bash
```

Or download and run the script manually:

```bash
wget https://raw.githubusercontent.com/Enterprise-Tooling-for-Symfony/dxcli/refs/heads/main/dxify.sh
chmod +x dxify.sh
./dxify.sh
```


## Usage

After installation, you can run commands using the `dx` command:

```bash
./dx <command>
```

To see available commands:

```bash
./dx
```


## Global Installation

To use the `dx` command from anywhere in your project, install it globally:

```bash
./dx .install-globally
```

This will install a wrapper script that allows you to run `dx` from any directory within your project.


## Creating Custom Commands

Create custom commands by adding shell scripts to the `.dxcli/subcommands` directory:

1. Copy the example script:
   ```bash
   cp .dxcli/subcommands/_example.sh .dxcli/subcommands/your-command.sh
   ```

2. Edit the script and update the metadata section:
   ```bash
   #@metadata-start
   #@name your-command
   #@description Description of what your command does
   #@metadata-end
   ```

3. Make your script executable:
   ```bash
   chmod +x .dxcli/subcommands/your-command.sh
   ```


## Installing Commands from Repositories

Install commands from external Git repositories:

```bash
./dx .install-commands <git-repository-url>
```


## Configuration File

Create a `.dxclirc` file in your project root to automatically install commands from specified repositories:

```
[install-commands]
https://github.com/your-org/your-commands-repo.git
git@github.com:your-org/another-commands-repo.git
```

When you run `dxify.sh`, it will automatically install commands from these repositories.


## Updating DX CLI

Update your DX CLI installation to the latest version:

```bash
./dx .update
```


## Command Structure

DX CLI has two types of commands:

1. **Subcommands**: Regular commands for project tasks
2. **Metacommands**: System commands that manage DX CLI itself (prefixed with a dot)


## Best Practices

- Create commands for repetitive tasks in your development workflow
- Share common commands across your team via Git repositories
- Use descriptive names and helpful descriptions for your commands
- Keep commands focused on a single responsibility
- Document command usage in the script itself


## Contributing

Contributions are welcome! Feel free to submit pull requests or open issues on GitHub.


## License

[MIT License](LICENSE)
