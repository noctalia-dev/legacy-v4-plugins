# Zed Provider

A launcher provider plugin that lets you search and open your Zed projects.

## About

Quickly open your Zed projects from Noctalia's launcher without navigating through your filesystem. The plugin reads your Zed workspace database to show recent projects and allows browsing folders directly.

## Preview

## Usage

Open the Noctalia launcher and type `>zed` followed by a search term.

- `>zed` - List recent projects
- `>zed query` - Search projects by name or path
- `>zed ~/path/` - Browse folders (add trailing `/` to enter directory)
- `>zed ~/path` - Search folders in current directory

### Folder Navigation

When browsing folders:
- Type `>zed ~/Documents/` to enter and list folders inside Documents
- Type `>zed ~/Doc` to search for folders matching "Doc" in home directory

Alternatively, you can trigger the provider by IPC with the command `qs -c noctalia-shell ipc call plugin:zed-provider toggle`.

You can bind this to a keyboard shortcut in your compositor. For example, in Niri:

```
Mod+Z { spawn-sh "qs -c noctalia-shell ipc call plugin:zed-provider toggle"; }
```

## Requirements

- Noctalia
- Zed code editor
- sqlite3
