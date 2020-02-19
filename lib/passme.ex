defmodule Passme do
  @moduledoc """
  Passme keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

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
end
