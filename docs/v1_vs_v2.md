## Difference between v1 and v2

### Version 1
In v1 there was single supervisor called `wormhole_task_supervisor`.
All wormhole callbacks were supervised by it.
It is pretty naive design decision because it prevents cascading timeouts.
For example, if this code is executed:
```
Wormhole.capture(fn ->
  Wormhole.capture(fn ->
    :timer.sleep :infinity
  end)
end, timeout: 500)
```

process topology like this is created
(dashed line represents callback response path):

![v1_example](v1_topology_example.png)

Outer callback times-out after 500 ms but its process continues to run for full
5 s, which is default timeout for inner callback.
Inner process continues to run forever.

### Version 2

In v2 the issue is resolved by removing single dedicated supervisor.
Each time `Wormhole.capture()` is called new supervisor, linked with
calling process is spawned.
Previous example generates topology like this:

![v1_example](v2_topology_example.png)

When outer caller times-out after 500 ms it terminates its (outer)
callback supervisor and all processes beneath it are terminated as well.
