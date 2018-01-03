defmodule Wormhole.Capture do
  require Logger

  alias Wormhole.Defaults


  def exec(callback, options) do
    capture(callback, options)
  end


  defp capture(callback, options) do
    timeout_ms   = Keyword.get(options, :timeout_ms)   || Defaults.timeout_ms
    crush_report = Keyword.get(options, :crush_report) || Defaults.crush_report
    stacktrace?  = Keyword.get(options, :stacktrace)   || Defaults.stacktrace

    {:ok, supervisor} = Task.Supervisor.start_link(restart: :temporary, shutdown: 50)

    callback = callback |> Wormhole.CallbackWrapper.wrap(crush_report, stacktrace?)
    task = Task.Supervisor.async_nolink(supervisor, callback)

    response = Task.yield(task, timeout_ms)

    supervisor_terminate(supervisor)
    task_demonitor(task)
    task_silence(task)

    response_format(response, timeout_ms)
  end

  defp supervisor_terminate(supervisor), do: Process.exit(supervisor, :normal)

  defp task_demonitor(task), do:
    task |> Map.get(:ref) |> Process.demonitor([:flush])

  defp task_silence(task), do:
    task |> Map.get(:pid) |> send({:wormhole_timeout, :silence})

  defp response_format({:ok,   state},  _)          do {:ok,    state} end
  defp response_format({:exit, reason}, _)          do {:error, reason} end
  defp response_format(nil,             timeout_ms) do {:error, {:timeout, timeout_ms}} end

end
