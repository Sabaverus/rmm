defmodule Passme.Chat.Script.Handler do
  @moduledoc false

  @callback start_step(map()) :: {:ok | :end, map()}
  @callback next_step(map()) :: map()
  @callback set_step_result(map(), String) :: {:ok | :error, map() | binary}

  @doc """
  Stops all inner processes of given script
  """
  @callback abort_wr(any()) :: :ok
  @callback end_script(Passme.Chat.State.t()) :: Passme.Chat.State.t()
end
