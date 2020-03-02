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

  def on_start(script) do
    {text, opts} = Passme.Chat.Interface.on_start_new_record(script)
    Bot.msg(script.parent_user, text, opts)
    script
  end

  def abort(%{parent_user: pu}) do
    Bot.msg(pu, "Adding new record has been cancelled")
  end

  def end_script(script) do
    new_record =
      script.data
      |> Map.put(:author, script.parent_user.id)
      |> Map.put(:chat_id, script.parent_chat.id)

    # Add record to chat where script is started
    ChatServer.add_record_to_chat(
      script.parent_chat.id,
      new_record,
      script.parent_user
    )

    script
  end
end
