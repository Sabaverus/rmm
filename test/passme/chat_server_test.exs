defmodule Passme.Chat.Server.Test do
  use Passme.DataCase

  alias Passme.Chat.Server
  alias Passme.Chat.Script
  alias Passme.Chat.Storage
  alias Passme.Chat.Script.RecordFieldEdit

  @chat %{
    id: 1992
  }
  @chat_new %{
    id: 1000
  }
  @chat_edit %{
    id: 10001
  }

  @user %{
    id: 889,
    username: "Saba"
  }

  @record %{
    name: "record name",
    value: "record value"
  }

  describe "Chat.Server" do
    test "handle_input/2 with active script send input to script" do
      Server.script_new_record(@chat_new.id, @user, @chat)
      Server.handle_input(@chat_new.id, "text from anything else")

      %{script: script} = Server.state(@chat_new.id)
      refute is_nil(script)
      assert script.data.name == "text from anything else"
    end

    test "create_record/3 creates record and stores them in chat storage" do
      refute is_nil(create_record(@chat.id))
    end
  end

  describe "Chat.Server Scripts: " do
    test "script_edit_record/5 starting script `Chat.Script.RecordFieldEdit` for chat process" do
      record = create_record(@chat_edit.id)
      Passme.Chat.relate_user_with_chat(@chat_edit.id, @user.id)
      Server.script_edit_record(@chat_edit.id, record.id, :name, @user, @chat_edit)
      %{script: %RecordFieldEdit{} = script} = Server.state(@chat_edit.id)
      refute is_nil(script)
    end
  end

  def create_record(chat_id) do
    Server.add_record_to_chat(chat_id, @record)

    %{storage: storage} = Server.state(chat_id)

    storage
    |> Storage.entries_list()
    |> Enum.find(nil, fn entry ->
      entry.name == @record.name and entry.value == @record.value
    end)
  end
end
