#!/usr/bin/env bash
# Smoke test for cog-ruby indexing pipeline
# Runs bin/cog-ruby on each fixture, validates with protoc --decode_raw,
# and checks for expected symbols in the output.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COG_RUBY="$PROJECT_ROOT/bin/cog-ruby"
FIXTURES="$SCRIPT_DIR/fixtures/indexing"
OUT_DIR="/tmp/cog-ruby-smoke"

PASS=0
FAIL=0
ERRORS=""

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Check prerequisites
if ! command -v protoc &>/dev/null; then
  echo "ERROR: protoc not found. Install protobuf to run smoke tests."
  exit 1
fi

if ! command -v ruby &>/dev/null; then
  echo "ERROR: ruby not found."
  exit 1
fi

check_symbol() {
  local decoded="$1"
  local symbol="$2"
  local fixture_name="$3"

  if grep -qF "$symbol" "$decoded"; then
    return 0
  else
    ERRORS="${ERRORS}  FAIL: ${fixture_name} missing symbol: ${symbol}\n"
    return 1
  fi
}

run_fixture() {
  local name="$1"
  local rb_file="$2"
  shift 2
  local expected_symbols=("$@")

  local scip_out="$OUT_DIR/${name}.scip"
  local decoded_out="$OUT_DIR/${name}.decoded"

  echo -n "  $name ... "

  # Index the file
  if ! ruby "$COG_RUBY" "$FIXTURES/$rb_file" --output "$scip_out" 2>/dev/null; then
    echo "FAIL (indexing error)"
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}  FAIL: ${name} indexing failed\n"
    return
  fi

  # Validate with protoc
  if ! protoc --decode_raw < "$scip_out" > "$decoded_out" 2>/dev/null; then
    echo "FAIL (protoc decode error)"
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}  FAIL: ${name} protoc decode failed\n"
    return
  fi

  # Check expected symbols
  local fixture_pass=true
  for sym in "${expected_symbols[@]}"; do
    if ! check_symbol "$decoded_out" "$sym" "$name"; then
      fixture_pass=false
    fi
  done

  if $fixture_pass; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL (missing symbols)"
    FAIL=$((FAIL + 1))
  fi
}

echo "cog-ruby smoke tests"
echo "===================="
echo ""
echo "Indexing fixtures:"

# 1. simple_project — module, class, constant, method, params, locals
run_fixture "simple_project" "simple_project/lib/simple.rb" \
  "Greeter#" \
  "Greeter#DEFAULT_GREETING." \
  'Greeter::Person`#' \
  'Greeter::Person`#initialize(2).' \
  'Greeter::Person`#SPECIES.' \
  'Greeter::Person`#greet(0).' \
  "local 0"

# 2. nested_modules — deep nesting, path-style constants
run_fixture "nested_modules" "nested_modules/lib/nested.rb" \
  "Foo#" \
  'Foo::Bar`#' \
  'Foo::Bar::Baz`#' \
  'Foo::Bar::Baz`#deep_method(0).' \
  'Foo::Bar::Qux`#' \
  'Foo::Bar::Qux`#path_method(0).'

# 3. attr_and_mixins — attr_*, include, ivars
run_fixture "attr_and_mixins" "attr_and_mixins/lib/model.rb" \
  "Serializable#" \
  "Model#" \
  "Model#name(0)." \
  "Model#id(0)." \
  "Serializable#to_h(0)." \
  'Model#`@id`.' \
  'Model#`@name`.'

# 4. blocks_and_lambdas — blocks, lambdas, multi-assignment
run_fixture "blocks_and_lambdas" "blocks_and_lambdas/lib/processor.rb" \
  "Processor#" \
  "Processor#transform(1)." \
  "Processor#with_lambda(0)." \
  "Processor#multi_assign(0)." \
  "local 0"

# 5. singleton_and_class_methods — class << self, @@cvars, $globals
run_fixture "singleton_and_class_methods" "singleton_and_class_methods/lib/registry.rb" \
  "Registry#" \
  "Registry#register(1)." \
  "Registry#all(0)." \
  'Registry#`@@instances`.' \
  '$app_name.'

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failures:"
  echo -e "$ERRORS"
  exit 1
fi

echo "All smoke tests passed."
