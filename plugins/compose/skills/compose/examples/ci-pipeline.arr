-- Workflow: lint + test, gate, build for multiple platforms, upload
let ci =
  (lint &&& test)
  >>> gate(require: [pass, pass])
in
ci
  >>> (build_linux(profile: static) *** build_macos(profile: release))
  >>> upload(tag: "v0.1.0")       -- ref: Bash("gh release create")
