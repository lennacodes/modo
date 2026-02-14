# Modo

Stop copying `.claude/` folders between projects.

Modo is a CLI tool that lets you build reusable [Claude Code](https://docs.anthropic.com/en/docs/claude-code) config presets and compose them per-project. Apply multiple presets with one command — `claude.md` files get compiled with section headers, `settings.json` files get deep-merged so permission lists combine instead of overwrite.

```
modo apply swift-conventions testing-rules my-permissions
```

This creates `.claude/claude.md` (compiled with section headers) and `.claude/settings.json` (deep-merged — permission arrays are unioned, not overwritten).

## Why

If you use Claude Code across multiple projects, you've probably:

- Copied the same `.claude/` setup between repos
- Lost track of which project has which version of your rules
- Wanted different combinations of configs for different project types
- Had to manually merge permission lists when combining configs

Modo solves this. Build your configs once as presets, compose them per-project.

## Install

Requires Swift 5.10+ (ships with Xcode 15.3+).

```sh
git clone https://github.com/lennacodes/modo.git
cd modo/modo
swift build -c release
cp .build/release/modo /usr/local/bin/modo
```

## Usage

```sh
# Create presets
modo new swift-app --description "Swift/SwiftUI conventions" --tags swift,macos
modo new testing-rules --description "Testing standards"

# Edit their content
modo edit swift-app              # opens claude.md in $EDITOR
modo edit swift-app --settings   # opens settings.json

# Preview
modo show swift-app

# Apply to a project (composes multiple presets)
cd ~/code/my-project
modo apply swift-app testing-rules

# Apply to a specific directory
modo apply swift-app --to ~/code/other-project

# Preview without writing files
modo apply swift-app testing-rules --dry-run
```

## How the merge works

**`claude.md`** — Each preset's content becomes a section. Markdown is preserved as-is.

```markdown
## Swift App

You are working on a Swift/SwiftUI macOS app.
Use SwiftData for persistence.

---

## Testing Rules

Write unit tests for all new logic.
Keep test files next to source files.
```

**`settings.json`** — Deep-merged recursively:

| Type | Strategy |
|------|----------|
| String arrays | Union (no duplicates) |
| Dict arrays | Concatenated |
| Nested objects | Merged recursively |
| Scalars | Last preset wins |

```
Preset A: {"permissions": {"allow": ["swift build"]}}
Preset B: {"permissions": {"allow": ["git push"]}}
Result:   {"permissions": {"allow": ["swift build", "git push"]}}
```

**`.gitignore`** — `.claude/` is appended if not already present.

**Backups** — Re-applying to a project that already has `.claude/` files automatically backs up the existing files to `.bak` before overwriting.

## Sharing presets

```sh
modo export swift-app --to ~/Desktop    # creates swift-app.modopreset.zip
modo import swift-app.modopreset.zip    # adds to your preset library
```

## All commands

| Command | Description |
|---------|-------------|
| `modo new <name>` | Create a preset |
| `modo new <name> --from <path>` | Create from an existing project's `.claude/` |
| `modo edit <name>` | Edit claude.md (`--settings` for settings.json, `--folder` for Finder) |
| `modo list` | List all presets |
| `modo show <name>` | Preview a preset |
| `modo apply <presets...>` | Compose and apply to current directory |
| `modo apply <presets...> --to <path>` | Apply to a specific directory |
| `modo apply <presets...> --dry-run` | Preview without writing |
| `modo export <name>` | Export as `.modopreset.zip` |
| `modo import <file>` | Import from `.modopreset.zip` |
| `modo remove <name>` | Delete a preset (`--force` to skip confirmation) |

## Storage

Presets live at `~/.config/modo/presets/`. Each preset is a directory:

```
~/.config/modo/presets/swift-app/
├── preset.json      # metadata (name, description, tags)
├── claude.md        # instructions for Claude Code
└── settings.json    # permissions and hooks (optional)
```

## Built with Claude Code

I'm a beginner developer and built Modo with the help of [Claude Code](https://docs.anthropic.com/en/docs/claude-code). If you find bugs or want to contribute, issues and PRs are welcome!

## License

MIT
