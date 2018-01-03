# Wormhole

![wormhole](wormhole.jpg)

## Difference between v1 and v2
In v1 callback that timed-out was left to run indefinitely.
In v2, callback is terminated when it times-out.
[Read more...](docs/v1_vs_v2.md)


## Description
Wormhole captures anything that is emitted out of the callback
(return value or error reason) and transfers it to the calling process
in the form `{:ok, state}` or `{:error, reason}`.

Wormhole invokes `callback` in separate process and
waits for message from callback process containing callback return value
if finished successfully or
error reason if callback process failed for any reason.

If `callback` execution is not finished within specified timeout,
`callback` process is killed and error returned.
Default timeout value is specified in `@timeout_ms`.
User can specify `timeout_ms` in `options` keyword list.

By default if callback fails stacktrace will **not** be returned.
User can set `stacktrace` option to `true` and in that case stacktrace will
be returned in response.
Note: `stacktrace` option works only if `crush_report` is not enabled.

By default there is no retry, but user can specify
`retry_count` and `backoff_ms` in `options`.
Default back-off time value is specified in `@backoff_ms`.

Note: `retry_count` specifies maximum number of times `callback` can be invoked.
More accurate name would be `try_count` but I think it would bring
more confusion than clarity, hence the name remains.

By default exceptions in callback-process are handled so that
supervisor does not generate CRUSH REPORT (when released - Exrm/Distillery).
This behavior can be overridden by setting `crush_report` to `true`.
Note:
  - Crush report is not generated in Elixir by default.
  - Letting exceptions propagate might be useful for
    some other applications too (e.g sentry client).

## Installation
Add to the list of dependencies:
```elixir
def deps do
  [
    {:wormhole, "~> 1.4"}
  ]
end
```
Add to the list of applications:
```elixir
def application do
  [applications: [:wormhole]]
end
```

## Examples

### Successful execution - returning callback return value
Unnamed function:
```elixir
iex> Wormhole.capture(fn-> :a end)
{:ok, :a}

```
Named function without arguments:
```elixir
iex> Wormhole.capture(&Process.list/0)
{:ok, [#PID<0.0.0>, #PID<0.3.0>, #PID<0.6.0>, #PID<0.7.0>, ...]}
```
Named function with arguments:
```elixir
iex> Wormhole.capture(Enum, :count, [[1,2,3]])
{:ok, 3}
```

Both versions with timeout explicitly set to 2 seconds:
```elixir
iex> Wormhole.capture(&Process.list/0, timeout_ms: 2_000)
{:ok, [#PID<0.0.0>, #PID<0.3.0>, #PID<0.6.0>, #PID<0.7.0>, ...]}

iex> Wormhole.capture(Enum, :count, [[1,2,3]], timeout_ms: 2_000)
{:ok, 3}
```

### Failed execution - returning failure reason
```elixir
defmodule Test do
  def f do
    raise "Hello"
  end
end

iex> Wormhole.capture(&Test.f/0)
{:error,
 {%RuntimeError{message: "Hello"},
  [{Test, :f, 0, [file: 'iex', line: 23]},
   {Wormhole, :"-send_return_value/1-fun-0-", 2,
    [file: 'lib/wormhole.ex', line: 75]}]}}

iex> Wormhole.capture(fn-> throw :foo end)
{:error,
 {{:nocatch, :foo},
  [{Wormhole, :"-send_return_value/1-fun-0-", 2,
    [file: 'lib/wormhole.ex', line: 75]}]}}

iex> Wormhole.capture(fn-> exit :foo end)
{:error, :foo}

```

### Retry
```elixir
iex> Wormhole.capture(&foo/0, [timeout_ms: 2_000, retry_count: 3, backoff_ms: 300])
```


### Usage pattern
```elixir
def ... do
  ...
  (&some_function/0) |> Wormhole.capture |> some_function_response_handler
  ...
end

def some_function_response_handler({:ok, response}) do
 ...
end
def some_function_response_handler({:error, error}) do
 ...
end
```
