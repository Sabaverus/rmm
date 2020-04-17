defmodule Passme.Chat.Permissions do
  @moduledoc false

  alias Passme.Repo, as: DB
  alias Passme.Chat.Permissions.Request

  import Ecto.Query, warn: false

  def record_permission(record, user_id) do
    # :private
    # :pending
    # :allowed

    cond do
      not record.private ->
        :allowed

      record.id == user_id ->
        :allowed

      permission_pending?(record.id, user_id) ->
        :pending

      true ->
        :private
    end
  end

  def request_permission(record, user_id) do
    %Request{}
    |> Request.changeset(%{
      user_id: user_id,
      record_id: record.id,
      init_time: DateTime.utc_now()
    })
    |> DB.insert()
  end

  def request(request_id) do
    DB.get(Request, request_id)
  end

  defp permission_pending?(record_id, user_id) do
    pendings = record_pendings(record_id, user_id)

    case List.first(pendings) do
      nil ->
        false

      pending ->
        if pending.end_time do
          false
        else
          true
        end
    end
  end

  defp record_pendings(record_id, user_id) do
    Request
    |> Request.where_user(user_id)
    |> Request.where_record(record_id)
    |> limit(5)
    |> order_by(desc: :init_time)
    |> DB.all()
  end
end
