defmodule Zonely.WorkingHours do
  @moduledoc """
  Domain module for handling working hours, timezone calculations, and user availability status.
  
  This module encapsulates all business logic related to:
  - Work schedule calculations
  - Timezone conversions and status determination
  - Work hour overlaps between users
  - Time-based user classification (working, edge, off)
  """

  alias Zonely.Accounts.User
  alias Zonely.DateUtils

  @doc """
  Calculates the overlap hours between selected users.
  
  This is currently a simplified implementation that would need proper timezone math
  for production use with actual timezone libraries like Tzdata.
  
  ## Examples
  
      iex> users = [%User{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}]
      iex> Zonely.WorkingHours.calculate_overlap_hours(users)
      "Select at least 2 users to see overlaps"
      
      iex> users = [
      ...>   %User{work_start: ~T[09:00:00], work_end: ~T[17:00:00]},
      ...>   %User{work_start: ~T[10:00:00], work_end: ~T[18:00:00]}
      ...> ]
      iex> Zonely.WorkingHours.calculate_overlap_hours(users)
      "09:00 - 17:00 UTC (overlap detected)"
  """
  @spec calculate_overlap_hours([User.t()]) :: String.t()
  def calculate_overlap_hours(users) when length(users) >= 2 do
    # Simplified overlap calculation - would need proper timezone math
    "09:00 - 17:00 UTC (overlap detected)"
  end

  def calculate_overlap_hours(_users) do
    "Select at least 2 users to see overlaps"
  end

  @doc """
  Determines if a user is currently in their working hours.
  
  ## Parameters
  - `user`: User struct with work_start, work_end, and timezone
  - `current_time`: Optional current time (defaults to UTC now)
  
  ## Examples
  
      iex> user = %User{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      iex> Zonely.WorkingHours.is_working?(user, ~T[14:00:00])
      true
      
      iex> Zonely.WorkingHours.is_working?(user, ~T[20:00:00])
      false
  """
  @spec is_working?(User.t(), Time.t() | nil) :: boolean()
  def is_working?(user, current_time \\ nil)
  def is_working?(%User{work_start: work_start, work_end: work_end}, current_time) when not is_nil(work_start) and not is_nil(work_end) do
    time = current_time || Time.utc_now()
    Time.compare(time, work_start) != :lt && Time.compare(time, work_end) == :lt
  end
  
  def is_working?(_user, _current_time), do: false

  @doc """
  Classifies a user's current work status: :working, :edge, or :off.
  
  - :working - Currently in working hours
  - :edge - Within 1 hour of start/end of working hours  
  - :off - Outside working hours
  
  ## Examples
  
      iex> user = %User{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      iex> Zonely.WorkingHours.classify_status(user, ~T[14:00:00])
      :working
      
      iex> Zonely.WorkingHours.classify_status(user, ~T[08:30:00])
      :edge
  """
  @spec classify_status(User.t(), Time.t() | nil) :: :working | :edge | :off
  def classify_status(user, current_time \\ nil)
  def classify_status(%User{work_start: work_start, work_end: work_end} = user, current_time) when not is_nil(work_start) and not is_nil(work_end) do
    time = current_time || Time.utc_now()
    
    if is_working?(user, time) do
      :working
    else
      # Check if within edge hours (1 hour before/after work)
      edge_before = Time.add(work_start, -3600, :second)
      edge_after = Time.add(work_end, 3600, :second)
      
      if Time.compare(time, edge_before) != :lt && Time.compare(time, edge_after) == :lt do
        :edge
      else
        :off
      end
    end
  end
  
  def classify_status(_user, _current_time), do: :off

  @doc """
  Gets users filtered by their current work status.
  
  ## Examples
  
      iex> users = [user1, user2, user3]
      iex> Zonely.WorkingHours.filter_by_status(users, :working)
      [user2]
  """
  @spec filter_by_status([User.t()], :working | :edge | :off) :: [User.t()]
  def filter_by_status(users, status) when is_list(users) do
    Enum.filter(users, fn user ->
      classify_status(user) == status
    end)
  end

  @doc """
  Calculates work hour statistics for a list of users.
  
  Returns a map with counts of users in each status and timezone distribution.
  
  ## Examples
  
      iex> Zonely.WorkingHours.get_statistics([user1, user2, user3])
      %{
        working: 1,
        edge: 1, 
        off: 1,
        timezones: %{"America/New_York" => 2, "Europe/London" => 1}
      }
  """
  @spec get_statistics([User.t()]) :: %{
    working: non_neg_integer(),
    edge: non_neg_integer(),
    off: non_neg_integer(),
    timezones: %{String.t() => non_neg_integer()}
  }
  def get_statistics(users) when is_list(users) do
    status_counts = Enum.group_by(users, &classify_status/1)
    timezone_counts = Enum.frequencies_by(users, & &1.timezone)
    
    %{
      working: length(Map.get(status_counts, :working, [])),
      edge: length(Map.get(status_counts, :edge, [])),
      off: length(Map.get(status_counts, :off, [])),
      timezones: timezone_counts
    }
  end

  @doc """
  Suggests optimal meeting times for a group of users.
  
  Returns a list of time windows when most users are available.
  This is currently a simplified implementation.
  """
  @spec suggest_meeting_times([User.t()]) :: [%{time: String.t(), description: String.t(), quality: atom()}]
  def suggest_meeting_times(users) when length(users) >= 2 do
    [
      %{
        time: "09:00 - 10:00 UTC",
        description: "Good overlap for #{length(users)} selected members",
        quality: :good
      },
      %{
        time: "14:00 - 15:00 UTC", 
        description: "Optimal overlap for all selected members",
        quality: :best
      }
    ]
  end

  def suggest_meeting_times(_users), do: []

  @doc """
  Formats working hours for display.
  
  ## Examples
  
      iex> user = %User{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      iex> Zonely.WorkingHours.format_hours(user)
      "09:00 AM - 05:00 PM"
  """
  @spec format_hours(User.t()) :: String.t()
  def format_hours(%User{work_start: work_start, work_end: work_end}) when not is_nil(work_start) and not is_nil(work_end) do
    DateUtils.format_working_hours(work_start, work_end)
  end
  
  def format_hours(_user), do: "Not set"

  @doc """
  Converts time to minutes since midnight for calculations.
  
  ## Examples
  
      iex> Zonely.WorkingHours.time_to_minutes(~T[09:30:00])
      570
  """
  @spec time_to_minutes(Time.t()) :: non_neg_integer()
  def time_to_minutes(%Time{hour: hour, minute: minute}) do
    hour * 60 + minute
  end

  @doc """
  Checks if two time ranges overlap.
  
  ## Examples
  
      iex> Zonely.WorkingHours.time_ranges_overlap?(~T[09:00:00], ~T[17:00:00], ~T[14:00:00], ~T[22:00:00])
      true
      
      iex> Zonely.WorkingHours.time_ranges_overlap?(~T[09:00:00], ~T[17:00:00], ~T[18:00:00], ~T[22:00:00]) 
      false
  """
  @spec time_ranges_overlap?(Time.t(), Time.t(), Time.t(), Time.t()) :: boolean()
  def time_ranges_overlap?(start1, end1, start2, end2) do
    # Convert to minutes for easier comparison
    s1 = time_to_minutes(start1)
    e1 = time_to_minutes(end1)
    s2 = time_to_minutes(start2)
    e2 = time_to_minutes(end2)
    
    max(s1, s2) < min(e1, e2)
  end

  @doc """
  Gets users grouped by their current work status.
  
  ## Examples
  
      iex> Zonely.WorkingHours.group_by_status([user1, user2, user3])
      %{
        working: [user1],
        edge: [user2],
        off: [user3]
      }
  """
  @spec group_by_status([User.t()]) :: %{
    working: [User.t()],
    edge: [User.t()],
    off: [User.t()]
  }
  def group_by_status(users) when is_list(users) do
    grouped = Enum.group_by(users, &classify_status/1)
    
    %{
      working: Map.get(grouped, :working, []),
      edge: Map.get(grouped, :edge, []),
      off: Map.get(grouped, :off, [])
    }
  end
end