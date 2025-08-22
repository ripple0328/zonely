defmodule Zonely.UserProfileTest do
  use ExUnit.Case, async: true
  
  alias Zonely.UserProfile
  alias Zonely.Accounts.User

  describe "avatar_data/2" do
    test "generates complete avatar data" do
      user = %User{name: "John Doe"}
      result = UserProfile.avatar_data(user, 64)
      
      assert Map.has_key?(result, :url)
      assert Map.has_key?(result, :fallback)
      assert is_binary(result.url)
      assert is_map(result.fallback)
    end
    
    test "uses default size when not specified" do
      user = %User{name: "Test User"}
      result = UserProfile.avatar_data(user)
      
      assert result.url =~ "size=64"
    end
  end

  describe "display_name/2" do
    test "returns regular name by default" do
      user = %User{name: "John Doe", name_native: "João Silva"}
      
      assert UserProfile.display_name(user) == "John Doe"
      assert UserProfile.display_name(user, :regular) == "John Doe"
    end
    
    test "returns native name when requested" do
      user = %User{name: "John Doe", name_native: "João Silva"}
      
      assert UserProfile.display_name(user, :native) == "João Silva"
    end
    
    test "falls back to regular name when no native name" do
      user = %User{name: "John Doe", name_native: nil}
      
      assert UserProfile.display_name(user, :native) == "John Doe"
    end
  end

  describe "has_different_native_name?/1" do
    test "returns true when native name differs" do
      user = %User{name: "Jose Garcia", name_native: "José García"}
      
      assert UserProfile.has_different_native_name?(user) == true
    end
    
    test "returns false when names are the same" do
      user = %User{name: "John Doe", name_native: "John Doe"}
      
      assert UserProfile.has_different_native_name?(user) == false
    end
    
    test "returns false when no native name" do
      user = %User{name: "John Doe", name_native: nil}
      
      assert UserProfile.has_different_native_name?(user) == false
    end
  end

  describe "completeness_percentage/1" do
    test "calculates completeness for fully filled profile" do
      user = %User{
        name: "John Doe",
        role: "Engineer", 
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        name_native: "John Doe",
        pronouns: "he/him",
        latitude: 40.7128,
        longitude: -74.0060
      }
      
      completeness = UserProfile.completeness_percentage(user)
      assert completeness == 100
    end
    
    test "calculates completeness for minimal profile" do
      user = %User{
        name: "John Doe",
        role: nil,
        timezone: nil,
        country: nil,
        work_start: nil,
        work_end: nil
      }
      
      completeness = UserProfile.completeness_percentage(user)
      assert completeness < 50
    end
    
    test "handles empty strings as unfilled fields" do
      user = %User{
        name: "John Doe",
        role: "",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      }
      
      completeness = UserProfile.completeness_percentage(user)
      # Should treat empty role as unfilled
      assert completeness < 100
    end
  end

  describe "summary/1" do
    test "returns comprehensive user summary" do
      user = %User{
        name: "John Doe",
        role: "Software Engineer",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      }
      
      summary = UserProfile.summary(user)
      
      assert summary.name == "John Doe"
      assert summary.role == "Software Engineer"
      assert summary.location == "United States of America"
      assert summary.status in [:working, :edge, :off]
      assert is_integer(summary.completeness)
    end
  end

  describe "search/2" do
    setup do
      users = [
        %User{name: "John Doe", role: "Software Engineer", country: "US"},
        %User{name: "Jane Smith", role: "Designer", country: "CA"},
        %User{name: "José García", role: "Product Manager", country: "ES", name_native: "José García"}
      ]
      {:ok, users: users}
    end
    
    test "searches by name", %{users: users} do
      results = UserProfile.search(users, "john")
      
      assert length(results) == 1
      assert hd(results).name == "John Doe"
    end
    
    test "searches by role", %{users: users} do
      results = UserProfile.search(users, "engineer")
      
      assert length(results) == 1
      assert hd(results).role == "Software Engineer"
    end
    
    test "searches by country", %{users: users} do
      results = UserProfile.search(users, "product")
      
      assert length(results) == 1
      assert hd(results).country == "ES"
    end
    
    test "searches by native name", %{users: users} do
      results = UserProfile.search(users, "josé")
      
      assert length(results) == 1
      assert hd(results).name_native == "José García"
    end
    
    test "case insensitive search", %{users: users} do
      results = UserProfile.search(users, "JOHN")
      
      assert length(results) == 1
      assert hd(results).name == "John Doe"
    end
    
    test "returns empty for no matches", %{users: users} do
      results = UserProfile.search(users, "nonexistent")
      
      assert results == []
    end
  end

  describe "filter_by_completeness/2" do
    setup do
      users = [
        %User{
          name: "Complete User",
          role: "Engineer",
          timezone: "UTC",
          country: "US", 
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00],
          name_native: "Complete",
          pronouns: "they/them"
        },
        %User{
          name: "Incomplete User",
          role: nil,
          timezone: nil,
          country: "US"
        }
      ]
      {:ok, users: users}
    end
    
    test "filters by completeness threshold", %{users: users} do
      complete_users = UserProfile.filter_by_completeness(users, 80)
      incomplete_users = UserProfile.filter_by_completeness(users, 10)
      
      assert length(complete_users) <= length(users)
      assert length(incomplete_users) == length(users)
    end
  end

  describe "group_by_completeness/1" do
    setup do
      users = [
        %User{
          name: "Complete User",
          role: "Engineer", 
          timezone: "UTC",
          country: "US",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00],
          name_native: "Complete",
          pronouns: "they/them",
          latitude: 40.0,
          longitude: -74.0
        },
        %User{
          name: "Mostly Complete User",
          role: "Designer",
          timezone: "UTC", 
          country: "CA",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00]
        },
        %User{
          name: "Incomplete User",
          role: nil,
          timezone: nil
        }
      ]
      {:ok, users: users}
    end
    
    test "groups users by completeness ranges", %{users: users} do
      grouped = UserProfile.group_by_completeness(users)
      
      assert Map.has_key?(grouped, :complete)
      assert Map.has_key?(grouped, :mostly_complete) 
      assert Map.has_key?(grouped, :incomplete)
      
      assert is_list(grouped.complete)
      assert is_list(grouped.mostly_complete)
      assert is_list(grouped.incomplete)
      
      total = length(grouped.complete) + length(grouped.mostly_complete) + length(grouped.incomplete)
      assert total == length(users)
    end
  end

  describe "get_statistics/1" do
    setup do
      users = [
        %User{
          name: "User 1",
          role: "Engineer",
          timezone: "UTC", 
          country: "US",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00],
          name_native: "Usuario 1"
        },
        %User{
          name: "User 2", 
          role: "Designer",
          timezone: "UTC",
          country: "CA",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00]
        }
      ]
      {:ok, users: users}
    end
    
    test "returns comprehensive statistics", %{users: users} do
      stats = UserProfile.get_statistics(users)
      
      assert stats.total_users == length(users)
      assert is_integer(stats.avg_completeness)
      assert is_integer(stats.complete_profiles)
      assert is_integer(stats.incomplete_profiles)
      assert is_integer(stats.has_native_names)
      
      assert stats.has_native_names == 1  # Only User 1 has different native name
    end
    
    test "handles empty user list" do
      stats = UserProfile.get_statistics([])
      
      assert stats.total_users == 0
      assert stats.avg_completeness == 0
    end
  end

  describe "initials/1" do
    test "extracts user initials" do
      user = %User{name: "John Doe"}
      
      assert UserProfile.initials(user) == "JD"
    end
    
    test "handles single name" do
      user = %User{name: "Madonna"}
      
      assert UserProfile.initials(user) == "M"
    end
  end

  describe "profile_complete?/1" do
    test "returns true for complete profile" do
      user = %User{
        name: "Complete User",
        role: "Engineer",
        timezone: "UTC",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        name_native: "Complete",
        pronouns: "they/them",
        latitude: 40.0,
        longitude: -74.0
      }
      
      assert UserProfile.profile_complete?(user) == true
    end
    
    test "returns false for incomplete profile" do
      user = %User{name: "Incomplete", role: nil}
      
      assert UserProfile.profile_complete?(user) == false
    end
  end

  describe "validation_errors/1" do
    test "returns errors for missing required fields" do
      user = %User{name: nil, role: nil, timezone: nil, country: nil}
      errors = UserProfile.validation_errors(user)
      
      assert "Name is required" in errors
      assert "Role is required" in errors
      assert "Timezone is required" in errors
      assert "Country is required" in errors
    end
    
    test "returns errors for invalid values" do
      user = %User{
        name: "Test",
        role: "Engineer",
        timezone: "Invalid/Timezone",
        country: "XX"
      }
      errors = UserProfile.validation_errors(user)
      
      assert "Invalid timezone format" in errors
      assert "Invalid country code" in errors
    end
    
    test "returns empty list for valid profile" do
      user = %User{
        name: "Valid User",
        role: "Engineer", 
        timezone: "America/New_York",
        country: "US"
      }
      errors = UserProfile.validation_errors(user)
      
      assert errors == []
    end
  end

  describe "edge cases and robustness" do
    test "handles users with minimal data" do
      user = %User{
        name: "Minimal",
        country: "US",
        timezone: "America/New_York",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      }
      
      # These should not crash
      assert is_integer(UserProfile.completeness_percentage(user))
      assert is_map(UserProfile.summary(user))
      assert is_boolean(UserProfile.profile_complete?(user))
    end
    
    test "handles empty search queries" do
      users = [%User{name: "Test User"}]
      results = UserProfile.search(users, "")
      
      # Empty query should return no results
      assert results == []
    end
  end
end