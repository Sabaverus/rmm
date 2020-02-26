defmodule Passme.Chat.State do
  @moduledoc false

  @type t :: %Passme.Chat.State{
    chat_id: integer(),
    storage: %Passme.Chat.Storage{},
    script: Passme.Chat.Script.Handler | nil,
    users: list()
  }

  defstruct chat_id: nil, storage: nil, script: nil, users: []

  import Logger

  alias Passme.Chat.Script, as: Script

  def new(chat_id, storage, script \\ nil) do
    %Passme.Chat.State{
      chat_id: chat_id,
      storage: storage,
      script: script,
      users: Passme.Chat.chat_users(chat_id)
    }
  end

  def script_abort(state) do
    Script.abort_wr(state.script)
    Map.put(state, :script, nil)
  end

  @spec get_storage(any()) :: Passme.Chat.Storage.t()
  def get_storage(state) do
    state.storage
  end

  @spec user_in_chat?(integer(), integer()) :: boolean
  def user_in_chat?(chat_id, user_id) when is_integer(chat_id) do
    Passme.Chat.user_in_chat?(chat_id, user_id)
  end

  @spec user_in_chat?(%Passme.Chat.State{}, integer()) :: boolean
  def user_in_chat?(state, user_id) do
    state.users
    |> Enum.find(nil, fn user ->
      user.user_id == user_id
    end)
    |> case do
      nil ->
        false
      user ->
        not user.removed
    end
  end

  def bind_user_to_chat(state, user_id) do

    new_users =
      if user_in_chat?(state, user_id) do
        state.users
      else
        Passme.Chat.relate_user_with_chat(state.chat_id, user_id)
        |> case do
          {:ok, user} ->
            [user | state.users]
          {:error, _changeset} ->
            warn("#{__MODULE__}.bind_user_to_chat problems while binding user to chat")
        end
      end
      Map.put(state, :users, new_users)
  end

  #### Private methods

end
