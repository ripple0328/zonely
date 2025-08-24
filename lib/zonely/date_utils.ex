defmodule Zonely.DateUtils do
  @moduledoc """
  Utilities for date formatting and calculations across the application.
  """

  @doc """
  Formats a date in a user-friendly format.

  ## Examples

      iex> Zonely.DateUtils.format_date(~D[2024-12-25])
      "December 25, 2024"

  """
  def format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  @doc """
  Calculates the number of days until a given date from today.

  Returns a positive number for future dates, negative for past dates,
  and 0 for today.

  ## Examples

      iex> Zonely.DateUtils.days_until(Date.add(Date.utc_today(), 5))
      5

      iex> Zonely.DateUtils.days_until(Date.add(Date.utc_today(), -3))
      -3

  """
  def days_until(date) do
    Date.diff(date, Date.utc_today())
  end

  @doc """
  Returns a human-readable string describing when a date occurs relative to today.

  ## Examples

      iex> Zonely.DateUtils.relative_date_text(Date.utc_today())
      "Today"

      iex> Zonely.DateUtils.relative_date_text(Date.add(Date.utc_today(), 1))
      "Tomorrow"

      iex> Zonely.DateUtils.relative_date_text(Date.add(Date.utc_today(), 5))
      "In 5 days"

  """
  def relative_date_text(date) do
    case days_until(date) do
      0 -> "Today"
      1 -> "Tomorrow"
      days when days > 1 -> "In #{days} days"
      days -> "#{abs(days)} days ago"
    end
  end

  @doc """
  Formats working hours from Time structs into a readable string.

  ## Examples

      iex> Zonely.DateUtils.format_working_hours(~T[09:00:00], ~T[17:00:00])
      "09:00 AM - 05:00 PM"

  """
  def format_working_hours(start_time, end_time) do
    "#{Calendar.strftime(start_time, "%I:%M %p")} - #{Calendar.strftime(end_time, "%I:%M %p")}"
  end

  @doc """
  Checks if a date falls within a given number of days from today.

  ## Examples

      iex> Zonely.DateUtils.within_days?(Date.add(Date.utc_today(), 3), 7)
      true

      iex> Zonely.DateUtils.within_days?(Date.add(Date.utc_today(), 10), 7)
      false

  """
  def within_days?(date, days) do
    days_until = days_until(date)
    days_until >= 0 && days_until <= days
  end

  @doc """
  Filters a list of items by their date field within a range.

  ## Examples

      iex> items = [%{date: Date.add(Date.utc_today(), 3)}, %{date: Date.add(Date.utc_today(), 10)}]
      iex> Zonely.DateUtils.filter_within_days(items, :date, 7)
      [%{date: ~D[...]}]  # Only the first item

  """
  def filter_within_days(items, date_field, days) do
    Enum.filter(items, fn item ->
      date = Map.get(item, date_field)
      within_days?(date, days)
    end)
  end

  @doc """
  Filters a list of items by their date field within a date range.

  ## Examples

      iex> items = [%{date: Date.add(Date.utc_today(), 3)}]
      iex> Zonely.DateUtils.filter_within_range(items, :date, 2, 7)
      [%{date: ~D[...]}]

  """
  def filter_within_range(items, date_field, min_days, max_days) do
    Enum.filter(items, fn item ->
      date = Map.get(item, date_field)
      days_until = days_until(date)
      days_until >= min_days && days_until <= max_days
    end)
  end
end
