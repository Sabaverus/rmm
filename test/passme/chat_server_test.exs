defmodule Passme.Chat.Server.Test do
  use Passme.DataCase

  alias Passme.Chat.Server
  alias Passme.Chat.Storage
  alias Passme.Chat.Storage.Record
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
      record = create_record(@chat.id)
      refute is_nil(record)
      assert record.chat_id == @chat.id
    end

    test "update_record/3 updates record by id with given fields" do
      chat_id = 99919
      record = create_record(chat_id)

      Server.update_record(chat_id, record.id, %{
        desc: "record description",
        value: "test string"
      })

      # Wait for Server message execution
      _state = Server.state(chat_id)

      updated = Passme.Chat.record(record.id)
      refute is_nil(updated)

      assert updated.value == "test string"
      assert updated.desc == "record description"
      assert record.name == updated.name
    end

    test "update_record/3 will not update record if record not found in chat" do

      chat_id = 29919
      another_chat = 2222222
      record = create_record(chat_id)

      Server.update_record(another_chat, record.id, %{
        name: "something"
      })

      # Wait for Server message execution
      _state = Server.state(chat_id)

      not_updated = Passme.Chat.record(record.id)
      assert record.name == not_updated.name
    end

    test "archive_record/2 must archive record related to chat state" do
      chat_id = 3123123
      record = create_record(chat_id)

      Server.archive_record(chat_id, record.id)

      # Wait for Server message execution
      _state = Server.state(chat_id)

      assert true == Passme.Chat.record(record.id) |> Record.archived?
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
    Server.create_record(chat_id, @record)

    %{storage: storage} = Server.state(chat_id)

    storage
    |> Storage.entries_list()
    |> Enum.find(nil, fn entry ->
      entry.name == @record.name and entry.value == @record.value
    end)
  end
end
