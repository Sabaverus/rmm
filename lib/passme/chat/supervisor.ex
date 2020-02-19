defmodule Passme.Chat.Supervisor do

  def start_link() do
    DynamicSupervisor.start_link(
      name: __MODULE__,
      strategy: :one_for_one
    )
  end

  def start_child(chat_id) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Passme.Chat.Server, chat_id}
    )
  end

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  def get_chat_process(chat_id) do
    case start_child(chat_id) do
      {:ok, pid} ->
        IO.puts("Process for chat ##{chat_id} is up")
        pid
      {:error, {:already_started ,pid}} -> pid
    end
  end
end
