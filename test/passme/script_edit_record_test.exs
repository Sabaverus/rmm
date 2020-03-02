defmodule Passme.EditRecordTest do
  use Passme.DataCase

  alias Passme.Chat
  alias Passme.Chat.Script
  alias Passme.Chat.Script.RecordFieldEdit

  @record %{
    name: "record name",
    value: "some value"
  }
  @chat %{
    id: :rand.uniform(1_000_000_000)
  }
  @user %{
    id: 42,
    username: "TestUser"
  }

  describe "Edit record" do
    test "on create must store previous value" do
      {:ok, record} = Chat.create_chat_record(@record)

      script = script_edit_record(record, :name)
      assert Map.get(script.data, :previous) == @record.name
    end

    test "set_step_result/2 must store value for dynamic key" do
      {:ok, record} = Chat.create_chat_record(@record)

      script = script_edit_record(record, :name)

      {:ok, script} = Script.set_step_result(script, "new name")
      assert Map.get(script.data, :name) == "new name"
    end

    test "end_script/1 must send request to chat server where is record updated" do
      Passme.Chat.Server.add_record_to_chat(@chat.id, @record)

      record =
        @chat.id
        |> Passme.Chat.Server.get_state()
        |> Passme.Chat.State.get_storage()
        |> Passme.Chat.Storage.entries_list()
        |> List.first()

      refute is_nil(record)

      script = script_edit_record(record, :name)

      {:ok, script} = Script.set_step_result(script, "new name")

      script
      |> Script.next_step()
      |> Script.end_script()

      {_, updated} =
        @chat.id
        |> Passme.Chat.Server.get_state()
        |> Passme.Chat.State.get_storage()
        |> Passme.Chat.Storage.get_record(record.id)

      refute is_nil(updated)
      assert Map.get(updated, :name) == "new name"
      assert Map.get(updated, :value) == @record.value
    end

    test "initial_data/2 must store edited key in record to script.data[:_field]" do
      {:ok, record} = Chat.create_chat_record(@record)
      data = RecordFieldEdit.initial_data(record, :name)
      assert Map.get(data, :_field) == :name
    end

    test "overriden get_field_key/1 must return correct key for set_step_value/1" do
      {:ok, record} = Chat.create_chat_record(@record)
      script = script_edit_record(record, :name)

      assert RecordFieldEdit.get_field_key(script) == :name
    end
  end

  def script_edit_record(record, key) do
    Script.start_script(
      RecordFieldEdit,
      @user,
      @chat,
      RecordFieldEdit.initial_data(record, key)
    )
  end
end
