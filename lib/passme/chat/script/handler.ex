defmodule Passme.Chat.Script.Handler do
  @moduledoc false

  @callback start_step(map()) :: map()
  @callback next_step(map()) :: map()
  @callback set_step_result(map(), String) :: {:ok | :error, map() | binary}

  @callback abort_wr(any()) :: :ok

  @callback end_script(Passme.Chat.Script.Handler.t()) :: {:ok, Passme.Chat.Script.Handler.t()}
end
