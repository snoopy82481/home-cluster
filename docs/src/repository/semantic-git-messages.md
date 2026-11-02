# Commit messages

Use Conventional Commits to describe the purpose of a change:

```text
type(scope): summary
```

The scope is optional. Keep the summary concise and use the imperative form.

| Type       | Use                                   |
| :--------- | :------------------------------------ |
| `feat`     | Add a capability or application       |
| `fix`      | Correct a problem                     |
| `docs`     | Change documentation                  |
| `refactor` | Restructure without changing behavior |
| `chore`    | Routine maintenance                   |
| `ci`       | Change repository automation          |
| `build`    | Change build tooling or dependencies  |
| `test`     | Add or change tests                   |
| `perf`     | Improve performance                   |
| `style`    | Change formatting                     |
| `revert`   | Revert a previous change              |

Examples:

```text
feat(networking): add echo service
fix(storage): correct snapshot class reference
docs: describe GitOps reconciliation
ci(docs): build documentation on pull requests
```

Sign off commits with `git commit -s`.
