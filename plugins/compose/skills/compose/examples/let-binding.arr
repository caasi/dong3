-- Let bindings: name and reuse workflow fragments

-- Basic let binding
let greet = \name -> hello(to: name) >>> respond in
greet(alice) >>> greet(bob)

-- Nested lets — multi-phase workflow
; let review = \trigger, fix ->
    loop(trigger >>> (pass ||| fix))
  in
  let phase1 = gather >>> review(check?, rework) in
  let phase2 = build >>> review(test?, fix) in
  phase1 >>> phase2

-- Let inside parentheses
; (let x = fetch(url: primary) in x)
  ||| fetch(url: mirror)

-- Let binding a value passed as positional arg
; let v = read(source: "config.yaml") >>> validate in
  deploy(env: staging, v)
