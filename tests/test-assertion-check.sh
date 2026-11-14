#!/usr/bin/env bash
# The assertion scan reads test files. It does not read git diffs.
set -uo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail=0
check() {
  if [ "$2" -eq "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (want rc=$2, got rc=$3)"; fail=1; fi
}
check_out() {
  if grep -q "$2" "$3"; then echo "ok   $1"; else echo "FAIL $1 (missing: $2)"; fail=1; fi
}

run_scan() {
  bash "$kit/scripts/assertion-check.sh" "$work/proj" >"$work/out" 2>&1
}

mkdir -p "$work/proj"
printf 'package p\nfunc TestOk(t *testing.T) {\n\tif false { t.Fatal("no") }\n}\n' > "$work/proj/ok_test.go"
run_scan; check "asserting go test passes" 0 $?
check_out "clean go says OK" "assertions: OK" "$work/out"

printf 'package p\nfunc TestEmpty(t *testing.T) {\n\tHelper()\n}\n' > "$work/proj/empty_test.go"
run_scan; check "empty go test warns" 0 $?
check_out "empty go test is named" "TestEmpty has no assertion" "$work/out"

PAIRING_STRICT=1 run_scan; check "empty go test fails when strict" 1 $?
check_out "strict failure is named" "PAIRING_STRICT=1" "$work/out"

mkdir -p "$work/proj/pkg"
printf 'def test_ok():\n    assert True\n' > "$work/proj/pkg/test_ok.py"
printf 'def test_empty():\n    helper()\n' > "$work/proj/pkg/test_empty.py"
# Keep the go failure so strict still fails, and the python name is present.
run_scan; check "python empty test is a warning by default" 0 $?
unset PAIRING_STRICT
run_scan
check_out "python empty test is named" "test_empty has no assertion" "$work/out"

# A committed assertion-free test is flagged even when the git diff is empty.
rm -rf "$work/proj"
mkdir -p "$work/proj"
git -C "$work/proj" init -q
printf 'package p\nfunc TestQuiet(t *testing.T) {\n\treturn\n}\n' > "$work/proj/quiet_test.go"
git -C "$work/proj" add quiet_test.go
git -C "$work/proj" -c user.email=t@example.invalid -c user.name=t commit -q -m init
run_scan; check "committed empty test still warns" 0 $?
check_out "scan saw the file not the diff" "TestQuiet has no assertion" "$work/out"

# --- Exclusions, fail-closed strict, bad root (step 1) ---
mk_empty_test() { mkdir -p "$(dirname "$1")"; printf 'def test_none():\n    helper()\n' > "$1"; }
scan_dir() { bash "$kit/scripts/assertion-check.sh" "$1" >"$work/out" 2>&1; }

for d in .venv venv node_modules vendor build dist target; do
  rm -rf "$work/ex"; mkdir -p "$work/ex"
  mk_empty_test "$work/ex/$d/lib/test_dep.py"
  scan_dir "$work/ex"; check "$d excluded rc" 0 $?
  check_out "$d excluded is OK" "assertions: OK" "$work/out"
done
rm -rf "$work/ex"; mkdir -p "$work/ex/odd"
printf 'home = /usr/bin\n' > "$work/ex/odd/pyvenv.cfg"
mk_empty_test "$work/ex/odd/lib/test_dep.py"
scan_dir "$work/ex"; check_out "pyvenv.cfg dir excluded" "assertions: OK" "$work/out"

rm -rf "$work/ex"; mkdir -p "$work/ex"
mk_empty_test "$work/ex/src/test_real.py"
scan_dir "$work/ex"; check_out "normal dir still reported" "test_none has no assertion" "$work/out"

for outer in node_modules vendor; do
  rm -rf "$work/o"; mkdir -p "$work/o/$outer/proj"
  mk_empty_test "$work/o/$outer/proj/test_real.py"
  scan_dir "$work/o/$outer/proj"
  check_out "root under $outer still scanned" "test_none has no assertion" "$work/out"
done

# Unreadable subdirectory: strict fails closed and names the path.
rm -rf "$work/ex"; mkdir -p "$work/ex/locked"
mk_empty_test "$work/ex/ok/test_ok.py"
printf 'def test_a():\n    assert 1\n' > "$work/ex/ok/test_ok.py"
chmod 000 "$work/ex/locked"
PAIRING_STRICT=1 scan_dir "$work/ex"; check "strict unreadable dir rc" 1 $?
check_out "unreadable path is named" "locked" "$work/out"
scan_dir "$work/ex"; check "default unreadable dir rc" 0 $?
check_out "default unreadable warns" "assertions: WARN" "$work/out"
chmod 755 "$work/ex/locked"

scan_dir "$work/does-not-exist"; check "missing root rc" 2 $?
printf x > "$work/afile"; scan_dir "$work/afile"; check "file root rc" 2 $?

# --- Table of near-miss inputs (step 2) ---
# Row: name | filename | source (printf escapes) | expect ("flag:<name>" or "clean")
table_row() {
  local name="$1" file="$2" src="$3" expect="$4"
  rm -rf "$work/tb"; mkdir -p "$work/tb"
  printf '%b' "$src" > "$work/tb/$file"
  scan_dir "$work/tb"
  case "$expect" in
    clean) check_out "table: $name" "assertions: OK" "$work/out" ;;
    flag:*) check_out "table: $name" "${expect#flag:} has no assertion" "$work/out" ;;
    flagfile) check_out "table: $name" "$file: no expect or assert call" "$work/out" ;;
  esac
}
table_row "py assert only in comment" t_test.py 'def test_a():\n    # assert x == 1\n    helper()\n' flag:test_a
table_row "py assert only in string" t_test.py 'def test_a():\n    msg = "assert x == 1"\n    helper()\n' flag:test_a
table_row "py assertEqual helper" t_test.py 'class T:\n    def test_a(self):\n        self.assertEqual(1, 1)\n' clean
table_row "py pytest.raises context" t_test.py 'def test_a():\n    with pytest.raises(ValueError):\n        f()\n' clean
table_row "py skipped test" t_test.py '@pytest.mark.skip\ndef test_a():\n    helper()\n' flag:test_a
table_row "py non-test helper" t_test.py 'def helper():\n    return 1\n' clean
table_row "go assertion only in comment" x_test.go 'package p\nfunc TestA(t *testing.T) {\n\t// t.Fatal("x")\n\tF()\n}\n' flag:TestA
table_row "go t.Run closure asserts" x_test.go 'package p\nfunc TestA(t *testing.T) {\n\tt.Run("s", func(t *testing.T) {\n\t\tt.Fatal("x")\n\t})\n}\n' clean
table_row "go assertEqual helper" x_test.go 'package p\nfunc TestA(t *testing.T) {\n\tassertEqual(t, 1, 1)\n}\n' clean
table_row "go TestMain ignored" x_test.go 'package p\nfunc TestMain(m *testing.M) {\n\tos.Exit(m.Run())\n}\n' clean
table_row "go non-test Test-prefixed helper" x_test.go 'package p\nfunc TestHelper() {\n\tF()\n}\nfunc TestReal(t *testing.T) {\n\tt.Fatal("x")\n}\n' clean
table_row "go t.Skip only" x_test.go 'package p\nfunc TestA(t *testing.T) {\n\tt.Skip("later")\n}\n' flag:TestA
table_row "ts expect.assertions" a.test.ts 'it("a", () => {\n  expect.assertions(1);\n  f();\n});\n' clean
table_row "ts expect in comment only" a.test.ts '// expect(x).toBe(1)\nit("a", () => { f(); });\n' flagfile
table_row "ts skipped test" a.test.ts 'it.skip("a", () => { f(); });\n' flagfile
table_row "ts real expect" a.test.ts 'it("a", () => { expect(f()).toBe(1); });\n' clean

# --- Nested helpers inside a test body do not end the test ---
table_row "py nested helper then assert after" t_test.py 'def test_a():\n    def gh(x):\n        return x\n    assert gh(1) == 1\n' clean
table_row "py nested helper then no assert" t_test.py 'def test_a():\n    def gh(x):\n        return x\n    gh(1)\n' flag:test_a
table_row "py asserts only before nested def" t_test.py 'def test_a():\n    assert f()\n    def gh(x):\n        return x\n    gh(1)\n' clean
table_row "py class and def two deep then assert" t_test.py 'def test_a():\n    class Fake:\n        def run(self):\n            def inner():\n                return 1\n            return inner()\n    assert Fake().run() == 1\n' clean
table_row "py two deep then no assert" t_test.py 'def test_a():\n    class Fake:\n        def run(self):\n            return 1\n    Fake().run()\n' flag:test_a
table_row "py nested helper assert counts for test" t_test.py 'def test_a():\n    def check(x):\n        assert x\n    check(1)\n' clean
table_row "py method nested helper then assert" t_test.py 'class T:\n    def test_a(self):\n        def gh():\n            return 1\n        assert gh()\n    def test_b(self):\n        helper()\n' flag:test_b
table_row "py assert after test is not counted" t_test.py 'def test_a():\n    helper()\n\ndef util():\n    assert True\n' flag:test_a
table_row "py multiline string at column 0 then assert" t_test.py 'def test_a():\n    s = """\nx\n"""\n    assert s\n' clean
table_row "go func literal then t.Error after" x_test.go 'package p\nfunc TestA(t *testing.T) {\n\tf := func(x int) int {\n\t\treturn x\n\t}\n\tif f(1) != 1 {\n\t\tt.Error("bad")\n\t}\n}\n' clean
table_row "go func literal no assertion" x_test.go 'package p\nfunc TestA(t *testing.T) {\n\tf := func(x int) int {\n\t\treturn x\n\t}\n\tf(1)\n}\n' flag:TestA
table_row "ts nested helper arrow then expect" a.test.ts 'it("a", () => {\n  const mk = () => 1;\n  function other() { return 2; }\n  expect(mk() + other()).toBe(3);\n});\n' clean
table_row "ts nested helper no expect" a.test.ts 'it("a", () => {\n  const mk = () => 1;\n  mk();\n});\n' flagfile

printf '\n%s\n' "$fail"
exit "$fail"
