defmodule Passme.Chat.Script.Handler do
  @moduledoc false

  @callback start_step(map()) :: map()
  @callback next_step(map()) :: map()
  @callback set_step_result(map(), String) :: map()
end
