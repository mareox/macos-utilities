# macOS Utilities

macOS-specific automation scripts and utilities.

## Tools

- **Auto Mount Drive** - Automatic drive mounting on login
- **SMB Remount Shares** - Safe, serialized recovery for the PANW and Documents NAS mounts
- **Folder Sync to SMB** - Sync local folders to SMB shares
- **Shell configuration** - eza aliases and Starship variants in [`shell/`](shell/)

## Requirements

- macOS 10.x or later
- Bash or zsh

## Usage

### Shell configuration (mbp4x)

`shell/eza.zsh` owns the `ls`, `lc`, and depth-two `lt` aliases and is sourced
from `~/.zshrc`. eza and Starship must already be installed.
`lc` includes hidden files, Git status, and directories-first sorting.

`shell/starship-{context,pure,hydro,omarchy}.toml` owns the prompt variants.
Deploy each as a regular copy to `~/.config/starship-variants/{name}.toml`,
then copy the desired variant to `~/.config/starship.toml` (default: context).
`shell/starship.zsh` owns the `prompt-context`, `prompt-pure`, `prompt-hydro`,
`prompt-omarchy`, and historical `prompt-restore` selectors and is sourced
from `~/.zshrc`. Redeploy copies after editing the source.

Context uses a two-line layout: blue hostname, light path, mint Git branch,
amber change counts, muted separators, and lavender command duration.
The input marker is green on success and red on failure. It requires a
Nerd Font. Hostname is always shown; the other three themes show it only
over SSH. All themes show duration for commands taking at least two seconds.
Other shell settings, secrets, history, and sessions are not managed here.

Before deployment, preserve the affected local files in
`~/.config/shell-backups/` using a unique date-first name. To roll back,
restore the saved `.zshrc`, active Starship config, and affected variant files.
`prompt-restore` remains the existing historical-theme restore command.

## Contributing

Contributions welcome! Please open an issue or submit a pull request.

## License

[Choose appropriate license]
