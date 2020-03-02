defmodule Passme.ChatTest do
  use Passme.DataCase

  alias Passme.Chat

  describe "records" do
    @valid_record %{
      name: "some title",
      value: "record value"
    }
    @update_record %{
      name: "some updated title",
      value: "record updated value",
      key: "new key",
      desc: "new description"
    }
    @invalid_record %{
      name: "record with empty value"
    }

    def add_valid_record do
      {:ok, record} = Chat.create_chat_record(@valid_record)
      @valid_record = record
      refute is_nil(record.id)

      record
    end

    test "adding_valid_record" do
      record = add_valid_record()

      assert @valid_record.name == record.name
      assert @valid_record.value == record.value
      refute is_nil(record.id)
    end

    test "adding_invalid_record" do
      {:error, changeset} = Chat.create_chat_record(@invalid_record)
      assert Ecto.Changeset == changeset.__struct__
    end

    test "updating_valid_record" do
      record = add_valid_record()
      {:ok, record} = Chat.update_record(record, @update_record)

      assert @update_record.name == record.name
      assert @update_record.value == record.value
      assert @update_record.key == record.key
      assert @update_record.desc == record.desc
    end

    test "user_relate_to_chat" do
    end

    test "related_user_must_be_in_chat" do
    end

    test "chat_users" do
    end

    test "added_records_must_be_linked_to_chat" do
    end
  end
end
