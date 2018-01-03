defmodule Wormhole.CallbackWrapper do

  @doc """
  Prevent callback from generating crush report.
  """
  def wrap(callback, crush_report, stacktrace?) do
    fn -> callback |> catch_errors(crush_report, stacktrace?) end
  end


  defp catch_errors(callback, _crush_report=true, _stacktrace?) do
    callback.() |> scilence_task
  end
  defp catch_errors(callback, _crush_report=false, stacktrace?) do
    try do
      callback.() |> scilence_task
    rescue error ->
      exit(exit_arg(error, stacktrace?))
    catch key, error ->
      exit(exit_arg(key, error, stacktrace?))
    end
  end

  defp scilence_task(response) do
    # Do not send response to the caller if it already timed-out
    receive do
      {:wormhole_timeout, :silence} ->
        exit {:shutdown, :wormhole_timeout}
      after 0 ->
        response
    end
  end

  defp exit_arg(error, _stacktrace?=false), do:
    {:shutdown, error}
  defp exit_arg(error, _stacktrace?=true), do:
    {:shutdown, {error, System.stacktrace()}}

  defp exit_arg(key, error, _stacktrace?=false), do:
    {:shutdown, {key, error}}
  defp exit_arg(key, error, _stacktrace?=true), do:
    {:shutdown, {key, error, System.stacktrace()}}
end
