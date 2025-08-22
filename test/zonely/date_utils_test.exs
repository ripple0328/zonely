defmodule Zonely.DateUtilsTest do
  use ExUnit.Case, async: true
  
  alias Zonely.DateUtils

  describe "format_date/1" do
    test "formats date correctly" do
      date = ~D[2024-12-25]
      assert DateUtils.format_date(date) == "December 25, 2024"
    end
    
    test "handles different months" do
      assert DateUtils.format_date(~D[2024-01-01]) == "January 01, 2024"
      assert DateUtils.format_date(~D[2024-07-04]) == "July 04, 2024"
    end
  end

  describe "days_until/1" do
    test "calculates future days correctly" do
      future_date = Date.add(Date.utc_today(), 5)
      assert DateUtils.days_until(future_date) == 5
    end
    
    test "calculates past days correctly" do
      past_date = Date.add(Date.utc_today(), -3)
      assert DateUtils.days_until(past_date) == -3
    end
    
    test "returns 0 for today" do
      today = Date.utc_today()
      assert DateUtils.days_until(today) == 0
    end
  end

  describe "relative_date_text/1" do
    test "returns 'Today' for current date" do
      today = Date.utc_today()
      assert DateUtils.relative_date_text(today) == "Today"
    end
    
    test "returns 'Tomorrow' for next day" do
      tomorrow = Date.add(Date.utc_today(), 1)
      assert DateUtils.relative_date_text(tomorrow) == "Tomorrow"
    end
    
    test "returns future days text" do
      future_date = Date.add(Date.utc_today(), 5)
      assert DateUtils.relative_date_text(future_date) == "In 5 days"
    end
    
    test "returns past days text" do
      past_date = Date.add(Date.utc_today(), -3)
      assert DateUtils.relative_date_text(past_date) == "3 days ago"
    end
    
    test "handles single past day" do
      yesterday = Date.add(Date.utc_today(), -1)
      assert DateUtils.relative_date_text(yesterday) == "1 days ago"
    end
  end

  describe "format_working_hours/2" do
    test "formats working hours correctly" do
      start_time = ~T[09:00:00]
      end_time = ~T[17:00:00]
      
      assert DateUtils.format_working_hours(start_time, end_time) == "09:00 AM - 05:00 PM"
    end
    
    test "handles different times" do
      start_time = ~T[08:30:00]
      end_time = ~T[18:15:00]
      
      assert DateUtils.format_working_hours(start_time, end_time) == "08:30 AM - 06:15 PM"
    end
    
    test "handles noon correctly" do
      start_time = ~T[12:00:00]
      end_time = ~T[13:00:00]
      
      assert DateUtils.format_working_hours(start_time, end_time) == "12:00 PM - 01:00 PM"
    end
  end

  describe "within_days?/2" do
    test "returns true for dates within range" do
      date_in_range = Date.add(Date.utc_today(), 3)
      assert DateUtils.within_days?(date_in_range, 7) == true
    end
    
    test "returns false for dates outside range" do
      date_outside_range = Date.add(Date.utc_today(), 10)
      assert DateUtils.within_days?(date_outside_range, 7) == false
    end
    
    test "returns true for today" do
      today = Date.utc_today()
      assert DateUtils.within_days?(today, 7) == true
    end
    
    test "returns false for past dates" do
      past_date = Date.add(Date.utc_today(), -1)
      assert DateUtils.within_days?(past_date, 7) == false
    end
    
    test "returns true for exact boundary" do
      boundary_date = Date.add(Date.utc_today(), 7)
      assert DateUtils.within_days?(boundary_date, 7) == true
    end
  end

  describe "filter_within_days/3" do
    setup do
      today = Date.utc_today()
      items = [
        %{date: Date.add(today, 2), name: "Soon"},
        %{date: Date.add(today, 10), name: "Later"},
        %{date: Date.add(today, -1), name: "Past"}
      ]
      
      {:ok, items: items, today: today}
    end
    
    test "filters items within specified days", %{items: items} do
      result = DateUtils.filter_within_days(items, :date, 7)
      
      assert length(result) == 1
      assert hd(result).name == "Soon"
    end
    
    test "returns empty list when no items match", %{items: items} do
      result = DateUtils.filter_within_days(items, :date, 1)
      
      assert result == []
    end
    
    test "handles empty list" do
      result = DateUtils.filter_within_days([], :date, 7)
      
      assert result == []
    end
  end

  describe "filter_within_range/4" do
    setup do
      today = Date.utc_today()
      items = [
        %{date: Date.add(today, 1), name: "Tomorrow"},
        %{date: Date.add(today, 5), name: "This week"},
        %{date: Date.add(today, 15), name: "Next week"},
        %{date: Date.add(today, 35), name: "Next month"}
      ]
      
      {:ok, items: items}
    end
    
    test "filters items within date range", %{items: items} do
      result = DateUtils.filter_within_range(items, :date, 2, 20)
      
      assert length(result) == 2
      names = Enum.map(result, & &1.name)
      assert "This week" in names
      assert "Next week" in names
    end
    
    test "includes boundary dates", %{items: items} do
      result = DateUtils.filter_within_range(items, :date, 1, 1)
      
      assert length(result) == 1
      assert hd(result).name == "Tomorrow"
    end
    
    test "returns empty list when no items in range", %{items: items} do
      result = DateUtils.filter_within_range(items, :date, 50, 100)
      
      assert result == []
    end
  end

  describe "edge cases and robustness" do
    test "handles leap year dates correctly" do
      leap_date = ~D[2024-02-29]
      formatted = DateUtils.format_date(leap_date)
      
      assert formatted == "February 29, 2024"
    end
    
    test "consistent behavior with different timezones" do
      # DateUtils should work with Date structs regardless of timezone context
      date = ~D[2024-06-15]
      days = DateUtils.days_until(date)
      
      assert is_integer(days)
    end
    
    test "format_working_hours handles edge times" do
      midnight = ~T[00:00:00]
      almost_midnight = ~T[23:59:59]
      
      result = DateUtils.format_working_hours(midnight, almost_midnight)
      
      assert result =~ "12:00 AM"
      assert result =~ "11:59 PM"
    end
  end
end