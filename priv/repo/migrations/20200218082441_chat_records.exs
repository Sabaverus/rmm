defmodule Passme.Repo.Migrations.ChatRecords do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:chat_records) do
      add :name, :string
      add :value, :string
      add :key, :string
      add :desc, :string
      add :author, :bigint
      add :chat_id, :bigint
      add :archived, :boolean, default: false

      timestamps()
    end
  end
end
