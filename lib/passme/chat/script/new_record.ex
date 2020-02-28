defmodule Passme.Chat.Script.NewRecord do
  @moduledoc false

  alias Passme.Chat.Script.Step
  alias Passme.Chat.Server, as: ChatServer
  alias Passme.Bot

  use Passme.Chat.Script.Base,
    steps: [
      {:name, Step.new("Enter record name", :value)},
      {:value, Step.new("Enter record value", :end)}
    ]

  def abort(%{parent_user: pu}) do
    Bot.msg(pu, "Adding new record has been cancelled")
  end

  def end_script(state) do
    new_storage =
      state.script.data
      |> Map.put(:author, state.script.parent_user.id)
      |> Map.put(:chat_id, state.script.parent_chat.id)
      |> Passme.Chat.create_chat_record()
      |> case do
        {:ok, entry} ->
          # Add record to chat where script is started
          ChatServer.add_record_to_chat(
            state.script.parent_chat.id,
            entry,
            state.script.parent_user
          )

          state.storage

        {:error, _changeset} ->
          Bot.msg(state.script.parent_user, "Error while adding new record")

          state.storage
      end

    # Return new chat state
    state
    |> Map.put(:storage, new_storage)
    # Script cleanup
    |> Map.put(:script, nil)
  end
end
