defmodule Passme.Repo.Migrations.ChatUsers do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:chat_users) do
      add :chat_id, :bigint
      add :user_id, :bigint
      add :removed, :boolean, default: false

      timestamps()
    end
  end
end
