---
type: project
area: code
created: 2026-07-21
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
