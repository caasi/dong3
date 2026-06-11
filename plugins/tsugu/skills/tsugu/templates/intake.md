status: open          # open | claimed | done | dropped
linked-branch:        # write-once breadcrumb set when status → claimed
landed:               # write-once; set at the done flip ONLY when landing is not
                      # containment-derivable (a forced squash). Validate before
                      # writing: the SHA must resolve and be contained in the
                      # fetched default ref.
## Observed source    (git-native self-note / agent-discovered / human-bridge: <ref>)
## Summary
## Related repos
## Initial guess
## Need human context
