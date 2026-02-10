defmodule Zonely.Repo.Migrations.CreateAnalyticsEvents do
  use Ecto.Migration

  def up do
    # Create analytics events table with monthly partitioning
    create table(:analytics_events, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :event_name, :string, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :session_id, :uuid, null: false
      add :user_context, :map, default: %{}
      add :metadata, :map, default: %{}
      add :properties, :map, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    # Indexes for common query patterns
    create index(:analytics_events, [:event_name, :timestamp])
    create index(:analytics_events, [:session_id, :timestamp])
    create index(:analytics_events, [:timestamp])

    # GIN index for JSON property queries (name_hash, etc.)
    create index(:analytics_events, [:properties], using: :gin)
    create index(:analytics_events, [:user_context], using: :gin)

    # Specific index for geographic queries
    execute("""
    CREATE INDEX analytics_events_country_idx 
    ON analytics_events ((user_context->>'country'))
    WHERE user_context->>'country' IS NOT NULL
    """)

    # Specific index for provider performance queries
    execute("""
    CREATE INDEX analytics_events_tts_provider_idx 
    ON analytics_events ((properties->>'tts_provider'))
    WHERE event_name = 'pronunciation_generated'
    """)

    # Add comment for documentation
    execute("""
    COMMENT ON TABLE analytics_events IS 
    'Privacy-first analytics events for SayMyName. No PII stored. 
    Names are hashed, sessions expire after 24h, no IP addresses.'
    """)
  end

  def down do
    drop table(:analytics_events)
  end
end
