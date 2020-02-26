defmodule Passme.Chat do
  @moduledoc false

  alias Passme.Repo, as: DB
  alias Passme.Chat.Storage.Record, as: Record

  def chat_records(chat_id) do
    Record
    |> Record.chat(chat_id)
    |> DB.all()
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

  @spec chat_users(integer()) :: list()
  def chat_users(chat_id) do

    Passme.Chat.Models.ChatUsers
    |> Passme.Chat.Models.ChatUsers.where_chat(chat_id)
    |> DB.all()
  end

  def relate_user_with_chat(chat_id, user_id) do
    %Passme.Chat.Models.ChatUsers{}
    |> Passme.Chat.Models.ChatUsers.changeset(%{
      chat_id: chat_id,
      user_id: user_id
    })
    |> DB.insert()
  end

  def user_in_chat?(chat_id, user_id) do
    Passme.Chat.Models.ChatUsers
    |> Passme.Chat.Models.ChatUsers.where_chat(chat_id)
    |> Passme.Chat.Models.ChatUsers.where_user(user_id)
    |> DB.one()
    |> case do
      nil -> false
      _ -> true
    end
  end
end
