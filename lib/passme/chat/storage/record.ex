defmodule Passme.Chat.Storage.Record do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Query, warn: false
  import Ecto.Changeset

  schema "chat_records" do
    field :key, :string
    field :desc, :string
    field :value, :string
    field :author, :integer
    field :chat_id, :integer

    timestamps()
  end

  @doc false
  def changeset(repo, attrs) do
    repo
    |> cast(attrs, [
      :key,
      :desc,
      :value,
      :author,
      :chat_id
    ])
    |> validate_required([:key, :value])
  end

  def user(query, user_id) do
    where(query, [record], record.author == ^user_id)
  end

  def chat(query, chat_id) do
    where(query, [record], record.chat_id == ^chat_id)
  end

  def map(%Passme.Chat.Storage.Record{} = record) do
    Map.from_struct(record)
  end

  @doc """
    Accept as parameter atom and return true if given field exits
  """
  @spec has_field?(atom()) :: boolean()
  def has_field?(field) when is_atom(field) do
    Map.has_key?(%__MODULE__{}, field)
  end

  def has_field?(_) do
    raise "#{__MODULE__}.has_field accept as parameter only atom type"
  end
end
