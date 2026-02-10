defmodule SayMyName.Repo.Migrations.CreateAnalyticsEvents do
  use Ecto.Migration

  def up do
    # Create extension for UUID generation
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
    
    # Create the parent table with partitioning by timestamp (daily)
    create table(:analytics_events, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("uuid_generate_v4()")
      add :event_name, :string, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :session_id, :string, null: false
      add :user_context, :map, default: %{}
      add :metadata, :map, default: %{}
      add :properties, :map, default: %{}
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
    end

    # Convert to partitioned table (by day)
    execute """
    -- Make the table partitioned
    ALTER TABLE analytics_events
    PARTITION BY RANGE (timestamp)
    """

    # Create indexes on the parent table
    create index(:analytics_events, [:event_name, :timestamp])
    create index(:analytics_events, [:session_id, :timestamp])
    create index(:analytics_events, [:timestamp])
    
    # GIN index for JSONB properties searches
    execute "CREATE INDEX analytics_events_properties_idx ON analytics_events USING GIN (properties)"
    execute "CREATE INDEX analytics_events_user_context_idx ON analytics_events USING GIN (user_context)"

    # Create initial partitions for the next 7 days
    for days_offset <- 0..6 do
      partition_date = Date.utc_today() |> Date.add(days_offset)
      next_date = Date.add(partition_date, 1)
      
      partition_name = "analytics_events_#{partition_date |> Date.to_string() |> String.replace("-", "_")}"
      
      execute """
      CREATE TABLE #{partition_name} PARTITION OF analytics_events
      FOR VALUES FROM ('#{partition_date}') TO ('#{next_date}')
      """
    end

    # Create function to automatically create future partitions
    execute """
    CREATE OR REPLACE FUNCTION create_analytics_partition()
    RETURNS trigger AS $$
    DECLARE
      partition_date DATE;
      partition_name TEXT;
      start_date TEXT;
      end_date TEXT;
    BEGIN
      partition_date := DATE(NEW.timestamp);
      partition_name := 'analytics_events_' || TO_CHAR(partition_date, 'YYYY_MM_DD');
      start_date := partition_date::TEXT;
      end_date := (partition_date + INTERVAL '1 day')::TEXT;
      
      -- Check if partition exists, create if not
      IF NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = partition_name
      ) THEN
        EXECUTE format(
          'CREATE TABLE %I PARTITION OF analytics_events FOR VALUES FROM (%L) TO (%L)',
          partition_name,
          start_date,
          end_date
        );
      END IF;
      
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Create trigger to auto-create partitions
    execute """
    CREATE TRIGGER analytics_partition_trigger
    BEFORE INSERT ON analytics_events
    FOR EACH ROW
    EXECUTE FUNCTION create_analytics_partition();
    """

    # Create retention policy function
    execute """
    CREATE OR REPLACE FUNCTION purge_old_analytics_partitions()
    RETURNS void AS $$
    DECLARE
      partition_record RECORD;
      cutoff_date DATE;
      partition_date DATE;
      retention_days INTEGER;
    BEGIN
      -- Get all analytics_events partitions
      FOR partition_record IN
        SELECT tablename 
        FROM pg_tables 
        WHERE tablename LIKE 'analytics_events_%' 
          AND schemaname = 'public'
      LOOP
        -- Extract date from partition name (analytics_events_YYYY_MM_DD)
        BEGIN
          partition_date := TO_DATE(
            SUBSTRING(partition_record.tablename FROM 'analytics_events_(.*)'),
            'YYYY_MM_DD'
          );
        EXCEPTION
          WHEN OTHERS THEN
            CONTINUE; -- Skip if date parsing fails
        END;
        
        -- Default retention: 90 days
        -- Override based on common event prefixes
        retention_days := 90;
        
        cutoff_date := CURRENT_DATE - INTERVAL '1 day' * retention_days;
        
        -- Drop partition if older than retention period
        IF partition_date < cutoff_date THEN
          EXECUTE format('DROP TABLE IF EXISTS %I', partition_record.tablename);
          RAISE NOTICE 'Dropped old partition: %', partition_record.tablename;
        END IF;
      END LOOP;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Create granular retention policy function that respects event types
    execute """
    CREATE OR REPLACE FUNCTION purge_old_analytics_events()
    RETURNS void AS $$
    DECLARE
      deleted_count INTEGER;
    BEGIN
      -- System events: 30 days
      DELETE FROM analytics_events
      WHERE event_name LIKE 'system_%'
        AND timestamp < NOW() - INTERVAL '30 days';
      GET DIAGNOSTICS deleted_count = ROW_COUNT;
      RAISE NOTICE 'Deleted % system events older than 30 days', deleted_count;
      
      -- Page views and interactions: 90 days
      DELETE FROM analytics_events
      WHERE (event_name LIKE 'page_view_%' OR event_name LIKE 'interaction_%')
        AND timestamp < NOW() - INTERVAL '90 days';
      GET DIAGNOSTICS deleted_count = ROW_COUNT;
      RAISE NOTICE 'Deleted % page_view/interaction events older than 90 days', deleted_count;
      
      -- Pronunciation events: 180 days
      DELETE FROM analytics_events
      WHERE event_name LIKE 'pronunciation_%'
        AND timestamp < NOW() - INTERVAL '180 days';
      GET DIAGNOSTICS deleted_count = ROW_COUNT;
      RAISE NOTICE 'Deleted % pronunciation events older than 180 days', deleted_count;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    # Drop triggers and functions
    execute "DROP TRIGGER IF EXISTS analytics_partition_trigger ON analytics_events"
    execute "DROP FUNCTION IF EXISTS create_analytics_partition()"
    execute "DROP FUNCTION IF EXISTS purge_old_analytics_partitions()"
    execute "DROP FUNCTION IF EXISTS purge_old_analytics_events()"
    
    # Drop all partitions
    execute """
    DO $$
    DECLARE
      partition_record RECORD;
    BEGIN
      FOR partition_record IN
        SELECT tablename 
        FROM pg_tables 
        WHERE tablename LIKE 'analytics_events_%' 
          AND schemaname = 'public'
      LOOP
        EXECUTE format('DROP TABLE IF EXISTS %I', partition_record.tablename);
      END LOOP;
    END $$;
    """
    
    # Drop parent table
    drop_if_exists table(:analytics_events)
  end
end
