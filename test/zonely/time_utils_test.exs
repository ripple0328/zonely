defmodule Zonely.TimeUtilsTest do
  use ExUnit.Case, async: true
  
  alias Zonely.TimeUtils
  
  describe "frac_to_utc/4" do
    test "converts fractions to UTC datetime range" do
      date = ~D[2023-12-01]
      
      # Test noon to 6 PM (0.5 to 0.75)
      {from_utc, to_utc} = TimeUtils.frac_to_utc(0.5, 0.75, "UTC", date)
      
      assert from_utc == ~U[2023-12-01 12:00:00Z]
      assert to_utc == ~U[2023-12-01 18:00:00Z]
    end
    
    test "handles reversed fractions correctly" do
      date = ~D[2023-12-01]
      
      # Test reversed order (should auto-correct)
      {from_utc, to_utc} = TimeUtils.frac_to_utc(0.75, 0.5, "UTC", date)
      
      assert from_utc == ~U[2023-12-01 12:00:00Z]
      assert to_utc == ~U[2023-12-01 18:00:00Z]
    end
    
    test "handles midnight crossover" do
      date = ~D[2023-12-01]
      
      # Test 10 PM to midnight (0.9167 to 1.0)
      {from_utc, to_utc} = TimeUtils.frac_to_utc(0.9167, 1.0, "UTC", date)
      
      assert from_utc.hour == 22
      assert to_utc.hour == 0
      assert to_utc.day == 2  # Next day
    end
  end
  
  describe "classify_user/3" do
    test "classifies user as working during work hours" do
      user = %{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      from_utc = ~U[2023-12-01 10:00:00Z]
      to_utc = ~U[2023-12-01 11:00:00Z]
      
      result = TimeUtils.classify_user(user, from_utc, to_utc)
      assert result == :working
    end
    
    test "classifies user as off when outside work hours" do
      user = %{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      from_utc = ~U[2023-12-01 22:00:00Z]
      to_utc = ~U[2023-12-01 23:00:00Z]
      
      result = TimeUtils.classify_user(user, from_utc, to_utc)
      assert result == :off
    end
    
    test "classifies user as edge when near work start" do
      user = %{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      from_utc = ~U[2023-12-01 08:30:00Z]  # 30 minutes before work
      to_utc = ~U[2023-12-01 08:45:00Z]
      
      result = TimeUtils.classify_user(user, from_utc, to_utc)
      assert result == :edge
    end
    
    test "classifies user as edge when near work end" do
      user = %{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      from_utc = ~U[2023-12-01 17:30:00Z]  # 30 minutes after work
      to_utc = ~U[2023-12-01 17:45:00Z]
      
      result = TimeUtils.classify_user(user, from_utc, to_utc)
      assert result == :edge
    end
  end
  
  describe "status_to_int/1" do
    test "converts status atoms to integers correctly" do
      assert TimeUtils.status_to_int(:working) == 2
      assert TimeUtils.status_to_int(:edge) == 1
      assert TimeUtils.status_to_int(:off) == 0
    end
  end
  
  describe "time_to_minutes/1" do
    test "converts time to minutes since midnight" do
      assert TimeUtils.time_to_minutes(~T[00:00:00]) == 0
      assert TimeUtils.time_to_minutes(~T[09:30:00]) == 570
      assert TimeUtils.time_to_minutes(~T[12:00:00]) == 720
      assert TimeUtils.time_to_minutes(~T[23:59:00]) == 1439
    end
  end
  
  describe "overlap?/4" do
    test "detects overlapping time ranges" do
      assert TimeUtils.overlap?(540, 600, 570, 630) == true  # 9-10 AM overlaps with 9:30-10:30 AM
      assert TimeUtils.overlap?(540, 570, 600, 630) == false # 9-9:30 AM doesn't overlap with 10-10:30 AM
      assert TimeUtils.overlap?(570, 630, 540, 600) == true  # Same as first but reversed
    end
    
    test "handles edge cases" do
      # Adjacent ranges (no overlap)
      assert TimeUtils.overlap?(540, 570, 570, 600) == false
      
      # Identical ranges (full overlap)
      assert TimeUtils.overlap?(540, 600, 540, 600) == true
      
      # One range inside another
      assert TimeUtils.overlap?(540, 660, 570, 630) == true
    end
  end
  
  describe "within_edge?/5" do
    test "detects times within edge of work hours" do
      # Work hours: 9 AM (540) to 5 PM (1020), edge: 60 minutes
      # Check 8:30 AM (510) - should be within edge of start
      assert TimeUtils.within_edge?(510, 540, 540, 1020, 60) == true
      
      # Check 5:30 PM (1050) - should be within edge of end  
      assert TimeUtils.within_edge?(1050, 1080, 540, 1020, 60) == true
      
      # Check 7 AM (420) - should be outside edge
      assert TimeUtils.within_edge?(420, 450, 540, 1020, 60) == false
    end
  end
  
  describe "format_time/1" do
    test "formats time with AM/PM correctly" do
      assert TimeUtils.format_time(~T[09:30:00]) == "09:30 AM"
      assert TimeUtils.format_time(~T[15:45:00]) == "03:45 PM"
      assert TimeUtils.format_time(~T[00:00:00]) == "12:00 AM"
      assert TimeUtils.format_time(~T[12:00:00]) == "12:00 PM"
    end
  end
  
  describe "utc_now/0" do
    test "returns current UTC time" do
      now = TimeUtils.utc_now()
      assert %DateTime{} = now
      assert now.time_zone == "Etc/UTC"
    end
  end
  
  describe "add_minutes/2" do
    test "adds minutes to datetime correctly" do
      dt = ~U[2023-12-01 10:00:00Z]
      result = TimeUtils.add_minutes(dt, 30)
      
      assert result == ~U[2023-12-01 10:30:00Z]
    end
    
    test "handles negative minutes" do
      dt = ~U[2023-12-01 10:30:00Z]
      result = TimeUtils.add_minutes(dt, -15)
      
      assert result == ~U[2023-12-01 10:15:00Z]
    end
    
    test "handles day boundary crossing" do
      dt = ~U[2023-12-01 23:45:00Z]
      result = TimeUtils.add_minutes(dt, 30)
      
      assert result == ~U[2023-12-02 00:15:00Z]
    end
  end
  
  describe "diff_minutes/2" do
    test "calculates difference in minutes correctly" do
      dt1 = ~U[2023-12-01 10:00:00Z]
      dt2 = ~U[2023-12-01 10:30:00Z]
      
      assert TimeUtils.diff_minutes(dt2, dt1) == 30
      assert TimeUtils.diff_minutes(dt1, dt2) == -30
    end
    
    test "handles day boundary differences" do
      dt1 = ~U[2023-12-01 23:30:00Z]
      dt2 = ~U[2023-12-02 00:30:00Z]
      
      assert TimeUtils.diff_minutes(dt2, dt1) == 60
    end
  end
  
  describe "to_utc/1" do
    test "converts naive datetime to UTC" do
      naive = ~N[2023-12-01 10:00:00]
      result = TimeUtils.to_utc(naive)
      
      assert result == ~U[2023-12-01 10:00:00Z]
      assert result.time_zone == "Etc/UTC"
    end
  end
end