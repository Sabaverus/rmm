defmodule Passme.Chat.Script do
  @moduledoc false

  alias Passme.Chat.Script.Handler

  @behaviour Handler

  @impl Handler
  def next_step(script), do: forward(script, :next_step, [script])

  @impl Handler
  def start_step(script), do: forward(script, :start_step, [script])

  @impl Handler
  def set_step_result(script, value), do: forward(script, :set_step_result, [script, value])

  @impl Handler
  @doc """
  Stops all inner processes of given script
  """
  def abort_wr(script), do: forward(script, :abort_wr, [script])

  @impl Handler
  @doc """
  Call script callback `end_script` with given script and chat state, wich returns modified `Passme.Chat.State`
  """
  @spec end_script(Handler, Passme.Chat.State.t()) :: Passme.Chat.State.t()
  def end_script(script, state), do: forward(state.script, :end_script, [script, state])

  @doc """
  Return `true` if last step on given script has key `:end` or `nil`.
  In another case returns `false`
  """
  @spec end?(Handler) :: boolean()
  def end?(script), do: forward(script, :end?, [script])

  @doc """
  Deleting all steps - messages for chat where is given chat is running
  """
  @spec cleanup(Handler) :: Hangler
  def cleanup(script), do: forward(script, :cleanup, [script])

  defp forward(script, fun, args) do
    apply(script.module, fun, args)
  end
end
