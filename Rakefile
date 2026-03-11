# frozen_string_literal: true

require "fileutils"
require "open3"
require "json"

PROJECT_ROOT = __dir__
COG_RUBY = File.join(PROJECT_ROOT, "bin", "cog-ruby")
FIXTURES_DIR = File.join(PROJECT_ROOT, "test", "fixtures")
INDEXING_DIR = File.join(FIXTURES_DIR, "indexing")
DEBUG_DIR = File.join(FIXTURES_DIR, "debug")
OUT_DIR = "/tmp/cog-ruby-smoke"

# Fixture definitions: name => { file:, symbols: [] }
INDEXING_FIXTURES = {
  "simple_project" => {
    file: "simple_project/lib/simple.rb",
    symbols: [
      "Greeter#",
      "Greeter#DEFAULT_GREETING.",
      'Greeter::Person`#',
      'Greeter::Person`#initialize(2).',
      'Greeter::Person`#SPECIES.',
      'Greeter::Person`#greet(0).',
      "local 0"
    ]
  },
  "nested_modules" => {
    file: "nested_modules/lib/nested.rb",
    symbols: [
      "Foo#",
      'Foo::Bar`#',
      'Foo::Bar::Baz`#',
      'Foo::Bar::Baz`#deep_method(0).',
      'Foo::Bar::Qux`#',
      'Foo::Bar::Qux`#path_method(0).'
    ]
  },
  "attr_and_mixins" => {
    file: "attr_and_mixins/lib/model.rb",
    symbols: [
      "Serializable#",
      "Model#",
      "Model#name(0).",
      "Model#id(0).",
      "Serializable#to_h(0).",
      'Model#`@id`.',
      'Model#`@name`.'
    ]
  },
  "blocks_and_lambdas" => {
    file: "blocks_and_lambdas/lib/processor.rb",
    symbols: [
      "Processor#",
      "Processor#transform(1).",
      "Processor#with_lambda(0).",
      "Processor#multi_assign(0).",
      "local 0"
    ]
  },
  "singleton_and_class_methods" => {
    file: "singleton_and_class_methods/lib/registry.rb",
    symbols: [
      "Registry#",
      "Registry#register(1).",
      "Registry#all(0).",
      'Registry#`@@instances`.',
      '$app_name.'
    ]
  }
}.freeze

# Debug fixture definitions: name => { file:, breakpoint_line:, prompt:, expected: [] }
DEBUG_FIXTURES = {
  "basic_debug" => {
    file: "basic_debug.rb",
    breakpoint_line: 8,
    prompt: <<~PROMPT,
      Debug the Ruby file %<path>s using the cog MCP debug tools:

      1. Use debug_launch with program: "ruby", args: ["%<path>s"], language: "ruby", stop_on_entry: true
      2. Use debug_breakpoint with action: "set", file: "%<path>s", line: %<line>d
      3. Use debug_run with action: "continue" to hit the breakpoint
      4. Use debug_inspect with scope: "locals" to list all local variables
      5. Use debug_run with action: "step_over"
      6. Use debug_inspect with scope: "locals" again
      7. Use debug_stop to end the session

      Output ONLY a JSON object with these fields:
      - "hit_breakpoint": true/false (did execution stop at the breakpoint?)
      - "locals_first_stop": object mapping variable names to their values at first stop
      - "locals_second_stop": object mapping variable names to their values after stepping
      - "error": null or error message string
    PROMPT
    expected: %w[total n]
  },
  "block_stepping" => {
    file: "block_stepping.rb",
    breakpoint_line: 7,
    prompt: <<~PROMPT,
      Debug the Ruby file %<path>s using the cog MCP debug tools:

      1. Use debug_launch with program: "ruby", args: ["%<path>s"], language: "ruby", stop_on_entry: true
      2. Use debug_breakpoint with action: "set", file: "%<path>s", line: %<line>d
      3. Use debug_run with action: "continue" to hit the breakpoint inside the .map block
      4. Use debug_inspect with scope: "locals" to list all local variables
      5. Use debug_run with action: "continue" to hit the breakpoint on the next iteration
      6. Use debug_inspect with scope: "locals" again
      7. Use debug_stop to end the session

      Output ONLY a JSON object with these fields:
      - "hit_breakpoint": true/false
      - "locals_first_stop": object mapping variable names to their values at first stop
      - "locals_second_stop": object mapping variable names to their values at second stop
      - "error": null or error message string
    PROMPT
    expected: %w[item doubled]
  },
  "exception_handling" => {
    file: "exception_handling.rb",
    breakpoint_line: 10,
    prompt: <<~PROMPT,
      Debug the Ruby file %<path>s using the cog MCP debug tools:

      1. Use debug_launch with program: "ruby", args: ["%<path>s"], language: "ruby", stop_on_entry: true
      2. Use debug_breakpoint with action: "set", file: "%<path>s", line: %<line>d
      3. Use debug_run with action: "continue" to hit the breakpoint in the rescue block
      4. Use debug_inspect with scope: "locals" to list all local variables
      5. Use debug_inspect with expression: "e" to get the exception object
      6. Use debug_inspect with expression: "e.message" to get the exception message
      7. Use debug_stop to end the session

      Output ONLY a JSON object with these fields:
      - "hit_breakpoint": true/false
      - "locals": object mapping variable names to their values
      - "exception_class": string name of the exception class (e.g. "ZeroDivisionError")
      - "exception_message": string message from the exception
      - "error": null or error message string
    PROMPT
    expected: %w[e]
  }
}.freeze

COG_MCP_CONFIG = {
  "mcpServers" => {
    "cog" => {
      "command" => "cog",
      "args" => ["mcp", "--debug-tools=core"]
    }
  }
}.freeze

def check_prerequisite(cmd, message)
  unless system("command -v #{cmd} >/dev/null 2>&1")
    abort "ERROR: #{message}"
  end
end

def run_indexing_fixture(name, rb_relative, expected_symbols)
  scip_out = File.join(OUT_DIR, "#{name}.scip")
  decoded_out = File.join(OUT_DIR, "#{name}.decoded")
  rb_path = File.join(INDEXING_DIR, rb_relative)

  print "  #{name} ... "

  # Index
  _out, err, status = Open3.capture3("ruby", COG_RUBY, rb_path, "--output", scip_out)
  unless status.success?
    puts "FAIL (indexing error)"
    return { pass: false, errors: ["#{name} indexing failed: #{err}"] }
  end

  # Decode with protoc
  decoded, err, status = Open3.capture3("protoc", "--decode_raw", stdin_data: File.binread(scip_out))
  unless status.success?
    puts "FAIL (protoc decode error)"
    return { pass: false, errors: ["#{name} protoc decode failed: #{err}"] }
  end
  File.write(decoded_out, decoded)

  # Check symbols
  errors = []
  expected_symbols.each do |sym|
    unless decoded.include?(sym)
      errors << "#{name} missing symbol: #{sym}"
    end
  end

  if errors.empty?
    puts "PASS"
    { pass: true, errors: [] }
  else
    puts "FAIL (missing symbols)"
    { pass: false, errors: errors }
  end
end

def run_debug_fixture(name, fixture, mcp_config_path)
  rb_path = File.join(DEBUG_DIR, fixture[:file])
  prompt = format(fixture[:prompt], path: rb_path, line: fixture[:breakpoint_line])

  print "  #{name} ... "

  out, err, status = Open3.capture3(
    "claude", "-p",
    "--output-format", "text",
    "--mcp-config", mcp_config_path,
    "--allowedTools", "mcp__cog__debug_launch,mcp__cog__debug_breakpoint,mcp__cog__debug_run,mcp__cog__debug_inspect,mcp__cog__debug_stop,mcp__cog__debug_stacktrace,mcp__cog__debug_sessions",
    "--permission-mode", "bypassPermissions",
    "--max-budget-usd", "1",
    prompt
  )

  unless status.success?
    puts "FAIL (claude -p error)"
    return { pass: false, errors: ["#{name}: claude -p failed: #{err}"] }
  end

  # Save raw output for debugging
  File.write(File.join(OUT_DIR, "#{name}.debug.txt"), out)

  # Try to extract JSON from the response
  json_match = out.match(/\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}/m)
  unless json_match
    puts "FAIL (no JSON in response)"
    return { pass: false, errors: ["#{name}: no JSON object in claude output"] }
  end

  begin
    result = JSON.parse(json_match[0])
  rescue JSON::ParserError => e
    puts "FAIL (invalid JSON)"
    return { pass: false, errors: ["#{name}: JSON parse error: #{e.message}"] }
  end

  # Check for error in response
  if result["error"]
    puts "FAIL (debug error)"
    return { pass: false, errors: ["#{name}: #{result['error']}"] }
  end

  # Check that breakpoint was hit
  unless result["hit_breakpoint"]
    puts "FAIL (breakpoint not hit)"
    return { pass: false, errors: ["#{name}: breakpoint was not hit"] }
  end

  # Check expected variables are present in locals
  errors = []
  locals = result["locals"] || result["locals_first_stop"] || {}
  fixture[:expected].each do |var|
    unless locals.key?(var) || locals.keys.any? { |k| k.include?(var) }
      errors << "#{name}: expected variable '#{var}' not found in locals: #{locals.keys.join(', ')}"
    end
  end

  if errors.empty?
    puts "PASS"
    { pass: true, errors: [] }
  else
    puts "FAIL (missing variables)"
    { pass: false, errors: errors }
  end
end

namespace :test do
  desc "Run indexing smoke tests on all fixtures"
  task :smoke do
    check_prerequisite("protoc", "protoc not found. Install protobuf to run smoke tests.")

    FileUtils.rm_rf(OUT_DIR)
    FileUtils.mkdir_p(OUT_DIR)

    puts "cog-ruby smoke tests"
    puts "===================="
    puts ""
    puts "Indexing fixtures:"

    pass = 0
    fail_count = 0
    all_errors = []

    INDEXING_FIXTURES.each do |name, fixture|
      result = run_indexing_fixture(name, fixture[:file], fixture[:symbols])
      if result[:pass]
        pass += 1
      else
        fail_count += 1
        all_errors.concat(result[:errors])
      end
    end

    puts ""
    puts "Results: #{pass} passed, #{fail_count} failed"

    if fail_count > 0
      puts ""
      puts "Failures:"
      all_errors.each { |e| puts "  FAIL: #{e}" }
      abort
    end

    puts "All smoke tests passed."
  end

  desc "Run a single indexing smoke test (e.g., rake test:smoke_one[simple_project])"
  task :smoke_one, [:name] do |_t, args|
    name = args[:name]
    abort "Usage: rake test:smoke_one[fixture_name]" unless name
    fixture = INDEXING_FIXTURES[name]
    abort "Unknown fixture: #{name}. Available: #{INDEXING_FIXTURES.keys.join(', ')}" unless fixture

    check_prerequisite("protoc", "protoc not found. Install protobuf to run smoke tests.")

    FileUtils.rm_rf(OUT_DIR)
    FileUtils.mkdir_p(OUT_DIR)

    puts "Indexing fixture:"
    result = run_indexing_fixture(name, fixture[:file], fixture[:symbols])

    if result[:pass]
      puts "\nPassed."
    else
      puts "\nFailures:"
      result[:errors].each { |e| puts "  FAIL: #{e}" }
      abort
    end
  end

  desc "Run debug smoke tests via claude -p with cog MCP debug tools"
  task :debug do
    check_prerequisite("claude", "claude CLI not found. Install Claude Code to run debug tests.")
    check_prerequisite("cog", "cog CLI not found. Install cog to run debug tests.")

    FileUtils.mkdir_p(OUT_DIR)

    # Write MCP config to temp file
    mcp_config_path = File.join(OUT_DIR, "mcp-config.json")
    File.write(mcp_config_path, JSON.pretty_generate(COG_MCP_CONFIG))

    puts "cog-ruby debug smoke tests"
    puts "=========================="
    puts ""
    puts "Debug fixtures (via claude -p + cog MCP):"

    pass = 0
    fail_count = 0
    all_errors = []

    DEBUG_FIXTURES.each do |name, fixture|
      result = run_debug_fixture(name, fixture, mcp_config_path)
      if result[:pass]
        pass += 1
      else
        fail_count += 1
        all_errors.concat(result[:errors])
      end
    end

    puts ""
    puts "Results: #{pass} passed, #{fail_count} failed"

    if fail_count > 0
      puts ""
      puts "Failures:"
      all_errors.each { |e| puts "  FAIL: #{e}" }
      abort
    end

    puts "All debug smoke tests passed."
  end

  desc "Run a single debug smoke test (e.g., rake test:debug_one[basic_debug])"
  task :debug_one, [:name] do |_t, args|
    name = args[:name]
    abort "Usage: rake test:debug_one[fixture_name]" unless name
    fixture = DEBUG_FIXTURES[name]
    abort "Unknown fixture: #{name}. Available: #{DEBUG_FIXTURES.keys.join(', ')}" unless fixture

    check_prerequisite("claude", "claude CLI not found. Install Claude Code to run debug tests.")
    check_prerequisite("cog", "cog CLI not found. Install cog to run debug tests.")

    FileUtils.mkdir_p(OUT_DIR)

    mcp_config_path = File.join(OUT_DIR, "mcp-config.json")
    File.write(mcp_config_path, JSON.pretty_generate(COG_MCP_CONFIG))

    puts "Debug fixture:"
    result = run_debug_fixture(name, fixture, mcp_config_path)

    if result[:pass]
      puts "\nPassed."
    else
      puts "\nFailures:"
      result[:errors].each { |e| puts "  FAIL: #{e}" }
      abort
    end
  end
end

desc "Run all tests (smoke + debug)"
task test: ["test:smoke", "test:debug"]

task default: :test
