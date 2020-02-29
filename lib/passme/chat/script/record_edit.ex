defmodule Passme.Chat.Script.RecordFieldEdit do
  @moduledoc false

  alias Passme.Chat.Script.Step
  alias Passme.Chat.Storage.Record
  alias Passme.Chat.Server, as: ChatServer
  alias Passme.Bot

  use Passme.Chat.Script.Base,
    steps: [
      {:field,
       Step.new(
         "Enter new value for selected field",
         :end,
         validate: &validate(&1),
         can_be_empty: &Record.field_can_be_empty?(&1)
       )},
      {:end,
       Step.new(
         "Field changed!",
         nil
       )}
    ]

  def abort(%{parent_user: pu}) do
    Bot.msg(pu, "Record field edit has been cancelled")
  end

  def end_script(script, state) do
    ChatServer.update_chat_record(script.parent_chat.id, script.data)
    Map.put(state, :script, nil)
  end

  # Overrided from Passme.Chat.Script.Base module
  # making step key :field dynamic, if field-key will be added in script data as :_field before
  # initialize script
  @spec get_field_key(Passme.Chat.Script.Base.t()) :: atom()
  defp get_field_key(%__MODULE__{data: %{_field: field}}) do
    field
  end

  defp validate(value) do
    if is_bitstring(value) or is_nil(value) do
      :ok
    else
      {:error, "Given value must be type of String"}
    end
  end
end
