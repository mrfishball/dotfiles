---
name: process-tasks
description: Work through a task list one sub-task at a time, pausing for approval between steps. Use when the user wants to execute a task list, or runs /process-tasks.
---

# Process a task list

1. Open the task list. If there are several in `tasks/`, ask which. Find the first unchecked sub-task.
2. Do only that sub-task, then run its verify step.
3. Mark it `[x]`, update "Relevant files", and stop. Summarize what changed and ask whether to continue. Don't start the next sub-task until the user says yes, unless they've told you to keep going.
4. When every sub-task under a parent is done, run the full test suite.
   - If it passes, mark the parent `[x]` and offer to commit with `/commit`.
   - If it fails, fix it before moving on.
5. Add tasks you discover along the way to the list instead of doing them silently.
