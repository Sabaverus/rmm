defmodule Passme.Repo.Migrations.CreateChatPermissionsRequest do
  use Ecto.Migration

  def change do
    create table(:chat_permissions_request) do
      add :user_id, :integer
      add :record_id, :integer
      add :init_time, :utc_datetime
      add :end_time, :utc_datetime, default: nil
    end
  end
end
