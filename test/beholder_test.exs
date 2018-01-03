defmodule BeholderTest do
  @moduledoc """
  This is not a real test.
  It is usefull to observe process topology when capture() calls are nested.
  """

  use ExUnit.Case

  @tag :observer
  test "observer" do
    :observer.start()
    Supervisor.start_child(Wormhole.Supervisor,
      %{
        id: :nesto,
        start: {__MODULE__, :start_wormhole, []},
        restart: :temporary,
      }
    )

    # :timer.sleep 10_000
  end

  def start_wormhole do
    Wormhole.capture(fn ->
      Process.register(self(), :wh_srv_1)
      Wormhole.capture(fn ->
        Process.register(self(), :wh_srv_2)
        Wormhole.capture(fn ->
          Process.register(self(), :wh_srv_3)
          :timer.sleep(20_000)
        end, timeout_ms: 16_000)
      end, timeout_ms: 17_000)
    end, timeout_ms: 19_000)
    |> IO.inspect(label: "WH result")
  end

end
