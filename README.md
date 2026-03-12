<div align="center">

# cog-ruby

**Ruby language extension for [Cog](https://github.com/trycog/cog-cli).**

SCIP-based code intelligence for Ruby projects using [Prism](https://github.com/ruby/prism).

[Installation](#installation) · [Code Intelligence](#code-intelligence) · [Debugging](#debugging) · [How It Works](#how-it-works) · [Development](#development)

</div>

---

## Installation

### Prerequisites

- [Ruby 3.3+](https://www.ruby-lang.org/) (ships with Prism built-in)
- [Cog](https://github.com/trycog/cog-cli) CLI installed

### Install

```sh
cog ext:install https://github.com/trycog/cog-ruby.git
cog ext:install https://github.com/trycog/cog-ruby --version=0.1.0
cog ext:update
cog ext:update cog-ruby
```

Cog downloads the tagged GitHub release tarball, then finalizes the local install with `chmod +x bin/cog-ruby`. `--version` matches an exact release version after optional `v` prefix normalization.

The extension version is defined once in `cog-extension.json`; the Ruby runtime reads that version from the manifest, release tags use `vX.Y.Z`, and the install flag uses the matching bare semver `X.Y.Z`.

---

## Code Intelligence

Configure file patterns in `.cog/settings.json`:

```json
{
  "code": {
    "index": [
      "lib/**/*.rb",
      "app/**/*.rb",
      "**/*.rake",
      "*.gemspec"
    ]
  }
}
```

Then build the index:

```sh
cog code:index
```

Query symbols:

```sh
cog code:query --find "User"
cog code:query --refs "initialize"
cog code:query --symbols lib/models/user.rb
```

A built-in file watcher automatically keeps the index up to date as files change — no manual re-indexing needed after the initial build.

| File Type | Capabilities |
|-----------|--------------|
| `.rb` | Go-to-definition, find references, symbol search, project structure |
| `.rake` | Same as `.rb` |
| `.gemspec` | Same as `.rb`, also used for project name discovery |

### Indexing Features

The Prism-based SCIP indexer supports:

- Modules and classes (including nested `Foo::Bar` paths)
- Singleton classes (`class << self`)
- Methods (with full parameter tracking: required, optional, rest, keyword, keyword rest, block)
- Constants
- Instance variables, class variables, and global variables (with read/write tracking)
- Local variables and parameters (scoped to method/block)
- `attr_reader`, `attr_writer`, `attr_accessor` (generates method and field symbols)
- `include`, `extend`, `prepend` references
- Blocks and lambdas (with parameter tracking)
- Multi-assignment (`a, b = 1, 2`)
- Doc comment extraction (contiguous `#` comments preceding definitions)
- Enclosing symbol relationships

---

## Debugging

Start the MCP debug server:

```sh
cog debug:serve
```

| Setting | Value |
|---------|-------|
| Debugger type | `dap` — Debug Adapter Protocol via `rdbg` |
| Adapter command | `rdbg --open --port :{port}` |
| Transport | TCP |
| Boundary markers | `<internal_frame>` |

Requires the [`debug`](https://github.com/ruby/debug) gem (`gem install debug`).

---

## How It Works

Cog invokes `cog-ruby` once per extension group. It expands matched files onto
argv, the script fans parsing work out across Ruby threads, and it emits
per-file progress events on stderr as files complete:

```
cog invokes:      bin/cog-ruby --output <output_path> <file_path> [file_path ...]
script executes:  Prism parse + AST walk for one or more documents
```

**Auto-discovery:**

| Step | Logic |
|------|-------|
| Workspace root | Walks up from each input file looking for `Gemfile`, then `*.gemspec`, then `.git` (fallback: file parent directory). |
| Package name | Parsed from gemspec `.name = "..."` field. Falls back to workspace directory name. |
| Indexed target | Every file expanded from `{files}`; output is one SCIP protobuf containing one document per input file. |

### Architecture

```
bin/
└── cog-ruby                    # Executable entry point (shebang script)
lib/
├── cog_ruby.rb                 # Main orchestration
└── cog_ruby/
    ├── cli.rb                  # CLI argument parsing
    ├── workspace.rb            # Workspace root discovery
    ├── analyzer.rb             # Prism AST visitor, symbol extraction
    ├── scope.rb                # Scope stack (module/class/method/block nesting)
    ├── symbol.rb               # SCIP symbol string formatting
    ├── scip.rb                 # SCIP protocol type definitions
    └── protobuf.rb             # Hand-rolled protobuf encoder
```

Zero external dependencies — uses only Prism, which is built into Ruby 3.3+.

---

## Development

### Run from source

```sh
bin/cog-ruby --output /tmp/index.scip /path/to/file.rb /path/to/other.rb
```

### Manual verification

```sh
# Generate SCIP output
bin/cog-ruby --output /tmp/test.scip test/fixtures/sample.rb

# Inspect with protoc
protoc --decode_raw < /tmp/test.scip
```

### Indexing diagnostics

Enable structured debug logging for per-file timing and memory snapshots:

```sh
COG_RUBY_DEBUG=1 bin/cog-ruby --output /tmp/test.scip test/fixtures/sample.rb 2> /tmp/cog-ruby-debug.log
```

With `COG_RUBY_DEBUG=1`, the indexer emits debug events for batch start/finish,
per-file start/finish, read/analyze stage timings, watchdog `file_still_running`
events, and memory snapshots. When run through `cog code:index` with Cog debug
logging enabled, those non-progress stderr lines are forwarded into
`.cog/cog.log` while progress JSON continues to drive the live TUI.

### Install locally

```sh
mkdir -p ~/.config/cog/extensions/cog-ruby
cp -R . ~/.config/cog/extensions/cog-ruby
chmod +x ~/.config/cog/extensions/cog-ruby/bin/cog-ruby
```

For normal use, Cog downloads the GitHub release source tarball first and then runs the manifest build command locally.

### Release

- Set the next version in `cog-extension.json`
- Tag releases as `vX.Y.Z` to match Cog's exact-version install flow
- Pushing a matching tag triggers GitHub Actions to verify the tag against `cog-extension.json`, run tests, and create a GitHub Release
- Cog installs from the release source tarball, but the extension still finalizes locally after download

---

<div align="center">
<sub>Built with <a href="https://www.ruby-lang.org">Ruby</a> and <a href="https://github.com/ruby/prism">Prism</a></sub>
</div>
