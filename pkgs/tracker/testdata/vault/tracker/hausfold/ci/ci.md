---
type: project
created: 2026-09-01
---
```base
filters:
  and:
    - 'type == "todo"'
    - 'file.folder == this.file.folder'
views:
  - type: table
    name: open
```
