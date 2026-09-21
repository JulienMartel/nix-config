---
type: area
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
