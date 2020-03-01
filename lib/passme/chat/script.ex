defmodule Passme.Chat.Script do
  @moduledoc false

  alias Passme.Chat.Script.Handler

  @behaviour Handler

  @doc """
  Switches step on script to next in steps list
  """
  def next_step(script), do: forward(script, :next_step, [script])

  @doc """
  Invokes current step on given script
  """
  def start_step(script), do: forward(script, :start_step, [script])

  @doc """
  Applies given value to current step on script
  """
  @spec set_step_result(Handler, binary() | integer()) :: {:ok, Handler} | {:error, binary()}
  def set_step_result(script, value), do: forward(script, :set_step_result, [script, value])

  @doc """
  Stops all inner processes of given script
  """
  @spec abort_wr(Handler) :: Handler
  def abort_wr(script), do: forward(script, :abort_wr, [script])

  @doc """
  Call script callback `end_script` with given script and chat state, wich returns modified `Passme.Chat.State`
  """
  @spec end_script(Handler) :: {:ok, Handler}
  def end_script(script), do: forward(script, :end_script, [script])

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

  @spec start_script(Passme.Chat.Script.Handler, map(), map()) :: Script.t()
  def start_script(module, user, chat) do
    forward(module, :new, [user, chat])
    |> start_step()
  end

  @spec start_script(Passme.Chat.Script.Handler, map(), map(), map()) :: Script.t()
  def start_script(module, user, chat, struct) do
    forward(module, :new, [user, chat, struct])
    |> start_step()
  end

  defp forward(%{module: module}, fun, args) do
    forward(module, fun, args)
  end

  defp forward(module, fun, args) do
    apply(module, fun, args)
  end
end
