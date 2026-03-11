# Ruby Debug Expectations Matrix

Debug fixture expectations for cog-ruby. Ruby's `debug` gem provides full variable visibility at all times — no build modes or optimization levels affect debug info.

## Matrix

| Fixture | Goal | Breakpoint | Expected Locals | Notes |
|---------|------|-----------|-----------------|-------|
| `basic_debug.rb` | Breakpoint + locals inspection | Line 8 (`total += n`) | `total`, `n` visible in scope | `total` starts at 0, increments each iteration |
| `block_stepping.rb` | Block iteration + variable capture | Line 7 (`doubled = item * 2`) | `item`, `doubled` visible per iteration | Values change each iteration: 10→20, 20→40, 30→60 |
| `exception_handling.rb` | Rescue flow + exception object | Line 10 (`puts "Error: ..."`) | `e` (ZeroDivisionError), `a`, `b`, `result` | Exception triggered by `safe_divide(10, 0)` |

## Variable Visibility by Fixture

### basic_debug.rb

```
Breakpoint: line 8
Iteration 1: total=0,  n=1
Iteration 2: total=1,  n=2
Iteration 3: total=3,  n=3
Iteration 4: total=6,  n=4
Iteration 5: total=10, n=5
Final result: 15
```

### block_stepping.rb

```
Breakpoint: line 7
Iteration 1: item=10, doubled=20
Iteration 2: item=20, doubled=40
Iteration 3: item=30, doubled=60
Final results: [20, 40, 60]
```

### exception_handling.rb

```
First call: safe_divide(10, 2)
  → No exception, result=5

Second call: safe_divide(10, 0)
  → Breakpoint in rescue block (line 10)
  → e=#<ZeroDivisionError: divided by 0>
  → result=nil (not yet assigned)
  → After rescue: result=0
  → Ensure block runs regardless
```

## Ruby Debug Notes

- The `debug` gem (rdbg) is Ruby's standard debugger since Ruby 3.1
- No compilation step needed — Ruby is interpreted, full debug info always available
- Block-local variables (`item`, `doubled`) are visible when stopped inside the block
- Exception objects captured with `=> e` are visible as local variables in the rescue clause
- Instance variables, class variables, and globals are inspectable at any breakpoint
