# <Feature Name> Implementation Plan

> **REQUIRED SUB-SKILL:** Use `codespec-test-driven-development` discipline for every behavior change.

**Goal:** <!-- 一句话目标 -->

**Architecture:** <!-- 2-3 句话总体方案 -->

**Tech Stack:** <!-- 关键技术/库 -->

---

## 0. Preparation

- [ ] 0.1 Identify test command(s) for this repo (e.g., `npm test`, `pytest`, `go test ./...`)
- [ ] 0.2 Identify formatting/lint command(s) if applicable

## 1. Scenario-driven TDD tasks

<!--
把 specs 里的每个 `#### Scenario:` 映射成一组 5 步 TDD 任务：
RED → VERIFY_RED → GREEN → VERIFY_GREEN → REFACTOR

每一步都要写清：
- Files: Create/Modify/Test 的精确路径
- Run: 要执行的命令
- Expected: 预期输出（FAIL/PASS/错误信息关键字）
-->

### Scenario: <capability>/<requirement>/<scenario>

- [ ] 1.1 [TDD][RED] Write failing test for: <scenario>
  - Files:
    - Test: `<path/to/test>`
  - Code (test):
    ```text
    <test code here>
    ```

- [ ] 1.2 [TDD][VERIFY_RED] Run test and confirm it fails for the right reason
  - Run: `<test command>`
  - Expected: FAIL with `<expected error message>`

- [ ] 1.3 [TDD][GREEN] Implement minimal production code to pass the test
  - Files:
    - Modify: `<path/to/file>`
  - Code:
    ```text
    <minimal implementation here>
    ```

- [ ] 1.4 [TDD][VERIFY_GREEN] Re-run test and confirm it passes
  - Run: `<test command>`
  - Expected: PASS

- [ ] 1.5 [TDD][REFACTOR] Refactor safely (keep tests green)
  - Notes: <!-- 去重/命名/抽取，不改变行为 -->

## 2. Integration & verification

- [ ] 2.1 Run full test suite
  - Run: `<full test command>`
  - Expected: PASS

- [ ] 2.2 Run lints/builds if applicable
  - Run: `<lint/build command>`
  - Expected: exit 0

## 3. Spec sync checklist

- [ ] 3.1 Confirm tasks.md checkboxes reflect actual work done
- [ ] 3.2 Confirm specs/design/proposal match implementation reality
