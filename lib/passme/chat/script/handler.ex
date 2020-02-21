defmodule Passme.Chat.Script.Handler do
  @moduledoc false

  @callback start_step(map()) :: {:ok | :end, map()}
  @callback next_step(map()) :: map()
  @callback set_step_result(map(), String) :: map()
  @callback end_script({any(), any(), map()}) :: {any(), any(), nil}
end
