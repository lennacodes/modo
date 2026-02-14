# Modo

A CLI tool for managing reusable Claude Code configuration presets. Build a library of `.claude/` configs and apply them to any project with one command.

---

## Installation

Requires Swift 5.10+ (ships with Xcode 15.3+).

```sh
git clone https://github.com/lennacodes/modo.git
cd modo/modo
swift build -c release
cp .build/release/modo /usr/local/bin/modo
```

---

## How It Works

Presets are stored at `~/.config/modo/presets/`. Each preset is a folder:

```
~/.config/modo/presets/swift-app/
├── preset.json        # Metadata (name, description, tags)
├── claude.md          # Instructions for Claude Code
└── settings.json      # Permissions and hooks (optional)
```

Names are sanitized to lowercase-hyphenated: "Swift App" becomes `swift-app/`.

When you run `modo apply`, Modo compiles your presets into a project's `.claude/` directory:

```
your-project/
├── .claude/
│   ├── claude.md        # Compiled from presets
│   ├── settings.json    # Deep-merged from presets
│   └── .modo.json       # Apply record (presets used, timestamp, version)
├── .gitignore           # Updated to include .claude/
└── ...
```

---

## Commands

### `modo new <name>`

Create a new preset.

```
modo new my-preset
modo new "Swift App" --description "Base config for Swift projects" --tags swift,ios,macos
modo new my-config --from ~/Desktop/my-existing-project    # Import from existing .claude/
```

### `modo edit <name>`

Open a preset's files for editing.

```
modo edit swift-app                # Opens claude.md in $EDITOR (or default text editor)
modo edit swift-app --settings     # Opens settings.json instead
modo edit swift-app --folder       # Opens preset folder in Finder
```

### `modo list`

List all presets with descriptions and tags.

### `modo show <name>`

Preview a preset's contents in the terminal (first 15 lines of each file).

### `modo apply <presets...>`

Apply one or more presets to a project. This is the core command.

```
modo apply swift-app
modo apply swift-app my-rules firefox-ext       # Merge multiple presets
modo apply swift-app --to ~/code/my-project     # Apply to a specific directory
modo apply swift-app --dry-run                  # Preview without writing files
```

**Merge behavior:**

| File | Strategy |
|------|----------|
| `claude.md` | Concatenated with `## Preset Name` section headers, separated by `---` |
| `settings.json` | Deep-merged: string arrays are unioned (no duplicates), dict arrays concatenated, nested dicts merged recursively, scalars use last-preset-wins |
| `.gitignore` | `.claude/` appended if not already present |
| `.modo.json` | Written with preset names, timestamp, and modo version |

Empty `claude.md` files are skipped. Presets without `settings.json` are skipped for the merge step.

**Deep merge example:**

Preset A: `{"permissions": {"allow": ["swift build"]}}`
Preset B: `{"permissions": {"allow": ["git push"]}}`
Result: `{"permissions": {"allow": ["swift build", "git push"]}}`

### `modo export <name>`

Export a preset as a shareable `.modopreset.zip` file.

```
modo export swift-app                    # Exports to current directory
modo export swift-app --to ~/Desktop     # Exports to specific directory
```

### `modo import <file>`

Import a preset from a `.modopreset.zip` file.

```
modo import swift-app.modopreset.zip
modo import ~/Downloads/firefox-ext.modopreset.zip
```

Fails if a preset with the same name already exists. Use `modo remove` first to replace.

### `modo remove <name>`

Delete a preset. Prompts for confirmation.

```
modo remove swift-app
modo remove swift-app --force    # Skip confirmation
```

Already-applied projects are not affected.

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `modo new <name>` | Create a preset |
| `modo new <name> --from <path>` | Create from existing project |
| `modo edit <name>` | Edit claude.md |
| `modo edit <name> --settings` | Edit settings.json |
| `modo edit <name> --folder` | Open in Finder |
| `modo list` | List all presets |
| `modo show <name>` | Preview contents |
| `modo apply <presets...>` | Apply to current directory |
| `modo apply <presets...> --to <path>` | Apply to specific directory |
| `modo apply <presets...> --dry-run` | Preview without writing |
| `modo export <name>` | Export as .modopreset.zip |
| `modo export <name> --to <path>` | Export to specific directory |
| `modo import <file>` | Import from .modopreset.zip |
| `modo remove <name>` | Delete a preset |
| `modo remove <name> --force` | Delete without confirmation |
| `modo --version` | Show version |
| `modo --help` | Show help |

---

## Shell Completions

```
# zsh (default on macOS)
mkdir -p ~/.zfunc
modo --generate-completion-script zsh > ~/.zfunc/_modo
# Add to ~/.zshrc (before compinit): fpath=(~/.zfunc $fpath)

# bash
modo --generate-completion-script bash > ~/.modo-completion.bash
echo 'source ~/.modo-completion.bash' >> ~/.bashrc

# fish
modo --generate-completion-script fish > ~/.config/fish/completions/modo.fish
```

---

## File Locations

| What | Path |
|------|------|
| Binary | `/usr/local/bin/modo` |
| Source | Clone from GitHub |
| Presets | `~/.config/modo/presets/` |
| Preset metadata | `~/.config/modo/presets/<name>/preset.json` |
| Preset instructions | `~/.config/modo/presets/<name>/claude.md` |
| Preset permissions | `~/.config/modo/presets/<name>/settings.json` |
| Applied config | `<project>/.claude/claude.md`, `<project>/.claude/settings.json` |
| Apply record | `<project>/.claude/.modo.json` |
| Exported preset | `<name>.modopreset.zip` |
