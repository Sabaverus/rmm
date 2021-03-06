defmodule Passme.Chat.Script.NewRecord do
  @moduledoc false

  alias Passme.Chat.Script.Step
  alias Passme.Chat.Script.Interface
  alias Passme.Chat.Server, as: ChatServer
  alias Passme.Bot

  use Passme.Chat.Script.Base,
    steps: [
      {:name, Step.new("Enter record name", :value)},
      {:value, Step.new("Enter record value", :privacy)},
      {
        :privacy,
        Step.new(
          Interface.yes_no("This record is private?"),
          :end,
          field: :private,
          type: :boolean
        )
      }
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
    # Add record to chat where script is started
    ChatServer.create_record(
      script.parent_chat.id,
      script.data,
      script.parent_user
    )

    script
  end
end
