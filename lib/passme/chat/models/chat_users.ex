defmodule Passme.Chat.Models.ChatUsers do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Query, warn: false
  import Ecto.Changeset

  schema "chat_users" do
    field :chat_id, :integer
    field :user_id, :integer
    field :removed, :boolean

    timestamps()
  end

  @doc false
  def changeset(repo, attrs) do
    repo
    |> cast(attrs, [
      :chat_id,
      :user_id,
      :removed
    ])
    |> validate_required([:chat_id, :user_id])
  end

  def where_chat(query, chat_id) do
    where(query, [entry], entry.chat_id == ^chat_id)
  end

  def where_user(query, user_id) do
    where(query, [entry], entry.user_id == ^user_id)
  end

  def not_removed(query) do
    where(query, [entry], entry.removed == false)
  end
end
