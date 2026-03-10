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
cog install https://github.com/trycog/cog-ruby.git
```

No compilation step — Cog runs `chmod +x bin/cog-ruby` and the extension is ready.

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

### Install locally

```sh
cog install .
```

---

<div align="center">
<sub>Built with <a href="https://www.ruby-lang.org">Ruby</a> and <a href="https://github.com/ruby/prism">Prism</a></sub>
</div>
