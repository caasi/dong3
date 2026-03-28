-- Unit value and type

-- Unit as a trigger — no meaningful input
() >>> start_server :: () -> Server

-- Unit in type annotations — both input and output positions
; healthcheck :: () -> Status

-- f() passes Unit as positional argument (not empty args)
; noop() >>> continue

-- Unit with question operator
; ()? >>> (ready ||| wait)
