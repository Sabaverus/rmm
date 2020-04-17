defmodule Passme.Chat.Permissions.Request do
  @moduledoc false
  use Ecto.Schema

  alias Passme.Repo, as: DB

  import Ecto.Query, warn: false
  import Ecto.Changeset

  schema "chat_permissions_request" do
    field :record_id, :integer
    field :user_id, :integer
    field :init_time, :utc_datetime
    field :end_time, :utc_datetime
  end

  @doc false
  def changeset(request, attrs) do
    request
    |> cast(attrs, [:user_id, :record_id, :init_time, :end_time])
    |> validate_required([:user_id, :record_id, :init_time])
  end

  def update(%__MODULE__{} = record, attrs) do
    record
    |> __MODULE__.changeset(attrs)
    |> DB.update()
  end

  def where_user(query, user_id) do
    where(query, [entry], entry.user_id == ^user_id)
  end

  def where_record(query, record_id) do
    where(query, [entry], entry.record_id == ^record_id)
  end
end
