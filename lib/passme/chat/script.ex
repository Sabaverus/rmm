defmodule Passme.Chat.Script do
  @moduledoc false

  import Passme.Chat.Script.Handler

  def next_step(script), do: forward(script, :next_step, [script])

  def start_step(script), do: forward(script, :start_step, [script])

  def set_step_result(script, value), do: forward(script, :set_step_result, [script, value])

  defp forward(script, fun, args) do
    apply(script.module, fun, args)
  end
end
