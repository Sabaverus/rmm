defmodule Passme.Chat.Script do
  @moduledoc false

  @behaviour Passme.Chat.Script.Handler

  def next_step(script), do: forward(script, :next_step, [script])

  def start_step(script), do: forward(script, :start_step, [script])

  def set_step_result(script, value), do: forward(script, :set_step_result, [script, value])

  def end_script({_, _, script} = state), do: forward(script, :end_script, [state])

  defp forward(script, fun, args) do
    apply(script.module, fun, args)
  end
end