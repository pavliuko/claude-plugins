---
description: "Review Swift PR for concurrency issues using the Swift Concurrency skill"
argument-hint: "[concise|learn]"
allowed-tools: ["Bash", "Glob", "Grep", "Read", "Task"]
---

# Swift Concurrency PR Review

Run a Swift concurrency review on a pull request using the specialized `review-agent` powered by the `swift-concurrency` skill.

**Arguments:** "$ARGUMENTS"

## Review Workflow:

1. **Dependency Check**

   Verify all required plugins are available:

   - Check if the `swift-concurrency` skill/plugin is installed and accessible
   - Record the result (plugin name, version if available, status)
   - If the plugin is NOT available:
     - Display an error message explaining the missing dependency
     - Exit immediately

2. **Parse Arguments**

   Parse the provided arguments to determine review mode:

   - `concise` - Professional code review: issues + fixes only, no learning resources
   - `learn` - Educational review: explanations, fixes, and learning resources **(DEFAULT)**

3. **Determine Review Scope**

   - Check if PR exists: `gh pr view --json number,headRefName,baseRefName`
   - If no PR exists, report that and exit
   - Get the PR's changed files: `gh pr diff --name-only`
   - Filter to only `.swift` files
   - If no Swift files changed, report that and exit

4. **Detect GitHub Base URL**

   Construct the base URL for clickable file links:
   - Run `git remote get-url origin` to get the remote URL
   - Use the PR's head branch from step 3
   - Parse owner/repo from the remote URL
   - Construct: `https://github.com/{owner}/{repo}/blob/{head_branch}/`
   - Store as `github_base`

5. **Launch Review Agent**

   Launch the `swift-concurrency-reviewer:review-agent` agent with the parsed configuration:

   ```
   Task tool with subagent_type: swift-concurrency-reviewer:review-agent
   Prompt: Review the following Swift files for concurrency issues.
           Mode: [concise|learn]
           Files: [list of changed Swift files]
   ```

6. **Format Final Output**

   The agent returns JSON with this structure:
   ```json
   {
     "total_issues": N,
     "issues": [{ "file", "lines", "category", "severity", "problem", "code", "fix", "explanation", "learn_url" }]
   }
   ```

   Parse the JSON and format output based on style. This is the ONLY output shown to the user.

   ### If no issues found:
   ```markdown
   ## Swift Concurrency Review ✓

   No concurrency issues found in the changed Swift files.

   **Files reviewed:**
   - [list of files]
   ```

   ### Concise Mode (`concise`):
   ````markdown
   ## Swift Concurrency Issues Found: N

   ### Issue 1: [Category]
   **File:** [`file.swift:lines`]({github_base}path/to/file.swift#L{start}-L{end})
   **Severity:** [High/Medium/Low]
   **Problem:** [problem]
   **Fix:**
   ```swift
   [fix code]
   ```

   ---

   [repeat for each issue]
   ````

   ### Learn Mode (`learn`):
   ````markdown
   ## Swift Concurrency Review

   Found N issues. Let's understand each one:

   ---

   ### Issue 1: [Category]

   **File:** [`file.swift:lines`]({github_base}path/to/file.swift#L{start}-L{end})
   **Severity:** [High/Medium/Low]

   **Current code:**
   ```swift
   [problematic code]
   ```

   **Why this is a problem:**
   [explanation]

   **Suggested fix:**
   ```swift
   [fix code]
   ```

   **Learn more:** [{category}]({learn_url})

   ---

   [repeat for each issue]
   ````

## Prerequisites:

- The `swift-concurrency` plugin must be installed
- A pull request must exist for the current branch

## Notes:

- The agent uses the Swift Concurrency skill as its source of truth
- All recommendations follow the skill's decision tree and patterns
- Learning URLs are fetched directly from https://fuckingapproachableswiftconcurrency.com/en/
- Reviews only files changed in the PR, not the entire codebase
