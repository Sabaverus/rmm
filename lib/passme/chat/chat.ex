defmodule Passme.Chat do
  @moduledoc false

  alias Passme.Repo, as: DB
  alias Passme.Chat.Storage.Record, as: Record

  def chat_records(chat_id) do
    Record
    |> Record.chat(chat_id)
    |> DB.all()
    |> Passme.Chat.Storage.new()
  end

  def chat_record(record_id, chat_id) do
    Record
    |> Record.chat(chat_id)
    |> DB.get(record_id)
  end

  def record(record_id) do
    DB.get(Record, record_id)
  end

  def get_chat_records_for_user(user_id, chat_id) do
    Record
    |> Record.user(user_id)
    |> Record.chat(chat_id)
    |> DB.all()
  end

  def create_chat_record(%Record{} = record) do
    create_chat_record(Record.map(record))
  end

  def create_chat_record(%{} = record) do
    %Record{}
    |> Record.changeset(record)
    |> DB.insert()
  end

  def update_record(%Record{} = record, attrs) do
    record
    |> Record.changeset(attrs)
    |> DB.update()
  end

  def archive_record(%Record{} = record) do
    record
    |> Record.changeset(%{archived: true})
    |> DB.update()
  end
end
