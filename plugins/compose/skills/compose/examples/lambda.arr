-- Lambda expressions: parameterized workflow fragments

-- Basic lambda — single parameter, bound and applied
let greet = \name -> hello(to: name) >>> respond in
greet(world)

-- Multi-param lambda — reusable review pattern
; let review = \trigger, fix -> loop(trigger >>> (pass ||| fix)) in
  review(check?, rework)

-- Let-bound pipeline as positional argument passed to a node
; let v = some_pipeline in
  push(remote: origin, v)

-- Lambda with type annotations
; let process = \url -> fetch(url: url) :: URL -> HTML
    >>> parse :: HTML -> Data
  in
  process(target)
