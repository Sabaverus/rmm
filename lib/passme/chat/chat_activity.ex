defmodule Passme.Chat.ChatActivity do
  @moduledoc false

  alias Passme.Chat.State, as: State

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, nil}
  end

  ##### Client #####

  @spec request(any(), Passme.Chat.State.t()) :: :ok
  def request(context, state) do
    GenServer.cast(__MODULE__, {:metrics, context, state})
  end

  ##### Server #####

  def handle_cast({:metrics, context, _state}, nil) do
    case context do
      %{from: user, message: %{chat: chat}} ->
        if chat.id !== user.id do
          unless State.user_in_chat?(chat.id, user.id) do
            Passme.Chat.relate_user_with_chat(chat.id, user.id)
          end
        end
      %{from: _user} -> :ok
    end
    {:noreply, nil}
  end

end
