defmodule Passme.Chat.Storage.Record do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Query, warn: false
  import Ecto.Changeset

  schema "chat_records" do
    field :name, :string
    field :value, :string
    field :key, :string
    field :desc, :string
    field :author, :integer
    field :chat_id, :integer
    field :private, :boolean, default: false
    field :archived, :boolean, default: false

    timestamps()
  end

  @doc false
  def changeset(repo, attrs) do
    repo
    |> cast(attrs, [
      :key,
      :desc,
      :name,
      :value,
      :author,
      :chat_id,
      :private,
      :archived
    ])
    |> validate_required(required_fields())
  end

  def user(query, user_id) do
    where(query, [record], record.author == ^user_id)
  end

  def chat(query, chat_id) do
    where(query, [record], record.chat_id == ^chat_id)
  end

  def archived(query, bool) do
    where(query, [record], record.archived == ^bool)
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

  def archived?(record) do
    Map.get(record, :archived)
  end

  @spec field_can_be_empty?(atom()) :: boolean()
  def field_can_be_empty?(field) do
    Enum.find(required_fields(), nil, fn required ->
      required == field
    end)
    |> case do
      nil -> true
      _ -> false
    end
  end

  defp required_fields() do
    [:name, :value]
  end
end
