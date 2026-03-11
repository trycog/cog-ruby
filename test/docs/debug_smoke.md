# Ruby Debug Walkthrough

Manual debug walkthrough for cog-ruby using the `debug` gem (rdbg) and `claude -p` for automated sessions.

## Prerequisites

- Ruby 3.3+
- `gem install debug` (ships with Ruby 3.1+ but ensure latest)
- cog CLI installed and on PATH
- `protoc` (for SCIP validation, optional)

## Fixture Files

| File | Purpose |
|------|---------|
| `test/fixtures/debug/basic_debug.rb` | Loop accumulation, breakpoint + locals |
| `test/fixtures/debug/block_stepping.rb` | Block iteration, variable capture |
| `test/fixtures/debug/exception_handling.rb` | begin/rescue/ensure flow |

## Manual Debug Session

### 1. Start the debug daemon

```bash
cog debug:serve
```

This launches the DAP adapter (`rdbg --open --port :<port>`) as configured in `cog-extension.json`.

### 2. Launch a debug target

```bash
cog debug:launch test/fixtures/debug/basic_debug.rb
```

### 3. Set a breakpoint

```bash
cog debug:breakpoint test/fixtures/debug/basic_debug.rb:8
```

This sets a breakpoint inside the `each` block on `total += n`.

### 4. Run to breakpoint

```bash
cog debug:run
```

Execution pauses at line 8.

### 5. Inspect local variables

```bash
cog debug:locals
```

Expected output should include:
- `total` — current accumulated sum (starts at 0)
- `n` — current element from the array

### 6. Step and continue

```bash
cog debug:step
cog debug:locals
cog debug:continue
```

After stepping, `total` should reflect the addition of `n`.

### 7. Disconnect

```bash
cog debug:disconnect
```

## Automated Session with `claude -p`

Use `claude -p` to orchestrate an entire debug session non-interactively. This sends a prompt to Claude Code which drives the debugger through cog's debug commands.

### Basic Debug — Verify Locals

```bash
claude -p "
Using cog debug commands, debug the file test/fixtures/debug/basic_debug.rb:

1. Start the debug server with: cog debug:serve
2. Launch the file: cog debug:launch test/fixtures/debug/basic_debug.rb
3. Set a breakpoint at line 8 (inside the each block): cog debug:breakpoint test/fixtures/debug/basic_debug.rb:8
4. Run to the breakpoint: cog debug:run
5. Inspect locals: cog debug:locals
6. Verify that 'total' and 'n' are visible in the output
7. Step once: cog debug:step
8. Inspect locals again and verify 'total' has changed
9. Continue to completion: cog debug:continue
10. Disconnect: cog debug:disconnect

Report which variables were visible and their values at each stop.
"
```

### Block Stepping — Verify Iteration Variables

```bash
claude -p "
Using cog debug commands, debug test/fixtures/debug/block_stepping.rb:

1. Start the debug server: cog debug:serve
2. Launch: cog debug:launch test/fixtures/debug/block_stepping.rb
3. Set breakpoint at line 7 (inside .map block): cog debug:breakpoint test/fixtures/debug/block_stepping.rb:7
4. Run: cog debug:run
5. At the breakpoint, inspect locals and verify 'item' and 'doubled' are visible
6. Continue to next iteration: cog debug:continue
7. Inspect locals again — 'item' should have the next value
8. Continue to completion: cog debug:continue
9. Disconnect: cog debug:disconnect

Report the values of 'item' and 'doubled' at each iteration stop.
"
```

### Exception Handling — Verify Rescue Flow

```bash
claude -p "
Using cog debug commands, debug test/fixtures/debug/exception_handling.rb:

1. Start the debug server: cog debug:serve
2. Launch: cog debug:launch test/fixtures/debug/exception_handling.rb
3. Set breakpoint at line 10 (rescue block): cog debug:breakpoint test/fixtures/debug/exception_handling.rb:10
4. Run: cog debug:run
5. Execution should pause in the rescue block after ZeroDivisionError
6. Inspect locals: cog debug:locals
7. Verify the exception object 'e' is visible with message 'divided by 0'
8. Continue: cog debug:continue
9. Disconnect: cog debug:disconnect

Report whether the exception object was visible and its message.
"
```

## Validation Expectations

| Fixture | Stop Point | Expected Locals |
|---------|-----------|-----------------|
| basic_debug.rb | Line 8 (1st hit) | `total = 0`, `n = 1` |
| basic_debug.rb | Line 8 (after step) | `total = 1`, `n = 1` |
| block_stepping.rb | Line 7 (1st hit) | `item = 10`, `doubled = 20` |
| block_stepping.rb | Line 7 (2nd hit) | `item = 20`, `doubled = 40` |
| exception_handling.rb | Line 10 | `e = #<ZeroDivisionError: divided by 0>` |
