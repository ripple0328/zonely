defmodule Zonely.UserProfile do
  @moduledoc """
  Domain module for handling user profile information, display logic, and profile-related business rules.
  
  This module encapsulates business logic related to:
  - Profile completeness and validation
  - Display name and native name handling
  - Avatar generation and management
  - Profile search and filtering
  - User status and availability display
  """

  alias Zonely.Accounts.User
  alias Zonely.AvatarService
  alias Zonely.Geography
  alias Zonely.WorkingHours

  @doc """
  Generates complete avatar data for a user including URL and fallback.
  
  ## Examples
  
      iex> user = %User{name: "John Doe"}
      iex> Zonely.UserProfile.avatar_data(user, 64)
      %{
        url: "https://api.dicebear.com/...",
        fallback: %{initials: "JD", class: "bg-gradient-..."}
      }
  """
  @spec avatar_data(User.t(), pos_integer()) :: %{url: String.t(), fallback: map()}
  def avatar_data(%User{name: name}, size \\ 64) do
    AvatarService.generate_complete_avatar(name, size)
  end

  @doc """
  Gets the display name for a user, handling native names appropriately.
  
  Returns the regular name by default, but can return native name when requested.
  
  ## Examples
  
      iex> user = %User{name: "Jose Garcia", name_native: "José García"}
      iex> Zonely.UserProfile.display_name(user)
      "Jose Garcia"
      
      iex> Zonely.UserProfile.display_name(user, :native)
      "José García"
  """
  @spec display_name(User.t(), :regular | :native) :: String.t()
  def display_name(%User{name: name}), do: name
  def display_name(%User{name: name}, :regular), do: name
  def display_name(%User{name_native: nil, name: name}, :native), do: name
  def display_name(%User{name_native: native_name}, :native) when is_binary(native_name), do: native_name
  def display_name(%User{name: name}, _), do: name

  @doc """
  Checks if a user has a native name that differs from their regular name.
  
  ## Examples
  
      iex> user = %User{name: "Jose Garcia", name_native: "José García"}
      iex> Zonely.UserProfile.has_different_native_name?(user)
      true
      
      iex> user = %User{name: "John Doe", name_native: "John Doe"}
      iex> Zonely.UserProfile.has_different_native_name?(user)
      false
  """
  @spec has_different_native_name?(User.t()) :: boolean()
  def has_different_native_name?(%User{name: name, name_native: native_name}) 
      when is_binary(native_name) and native_name != name do
    true
  end
  
  def has_different_native_name?(_user), do: false

  @doc """
  Gets profile completeness percentage based on filled fields.
  
  Considers required and optional fields to calculate completeness.
  
  ## Examples
  
      iex> user = %User{name: "John", role: "Engineer", timezone: "UTC", country: "US"}
      iex> Zonely.UserProfile.completeness_percentage(user)
      80
  """
  @spec completeness_percentage(User.t()) :: non_neg_integer()
  def completeness_percentage(%User{} = user) do
    required_fields = [:name, :role, :timezone, :country, :work_start, :work_end]
    optional_fields = [:name_native, :pronouns, :latitude, :longitude]
    
    required_filled = Enum.count(required_fields, &field_filled?(user, &1))
    optional_filled = Enum.count(optional_fields, &field_filled?(user, &1))
    
    total_fields = length(required_fields) + length(optional_fields)
    filled_fields = required_filled + optional_filled
    
    round(filled_fields / total_fields * 100)
  end

  defp field_filled?(%User{} = user, field) do
    case Map.get(user, field) do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  @doc """
  Gets a summary of user information for display purposes.
  
  ## Examples
  
      iex> Zonely.UserProfile.summary(user)
      %{
        name: "John Doe",
        role: "Engineer", 
        location: "United States",
        status: :working,
        completeness: 85
      }
  """
  @spec summary(User.t()) :: %{
    name: String.t(),
    role: String.t() | nil,
    location: String.t(),
    status: atom(),
    completeness: non_neg_integer()
  }
  def summary(%User{} = user) do
    %{
      name: display_name(user, :regular),
      role: user.role,
      location: Geography.country_name(user.country),
      status: WorkingHours.classify_status(user),
      completeness: completeness_percentage(user)
    }
  end

  @doc """
  Searches users by name, role, or country.
  
  Performs case-insensitive partial matching across multiple fields.
  
  ## Examples
  
      iex> users = [user1, user2, user3]
      iex> Zonely.UserProfile.search(users, "john")
      [%User{name: "John Doe"}]
      
      iex> Zonely.UserProfile.search(users, "engineer")
      [%User{role: "Software Engineer"}]
  """
  @spec search([User.t()], String.t()) :: [User.t()]
  def search(users, query) when is_list(users) and is_binary(query) do
    if query == "" or String.trim(query) == "" do
      []
    else
      normalized_query = String.downcase(query)
      
      Enum.filter(users, fn user ->
        String.contains?(String.downcase(user.name), normalized_query) ||
        String.contains?(String.downcase(user.role || ""), normalized_query) ||
        String.contains?(String.downcase(user.country || ""), normalized_query) ||
        (user.name_native && String.contains?(String.downcase(user.name_native), normalized_query))
      end)
    end
  end

  @doc """
  Filters users by profile completeness threshold.
  
  ## Examples
  
      iex> Zonely.UserProfile.filter_by_completeness(users, 80)
      [%User{}, %User{}]  # Users with >= 80% profile completion
  """
  @spec filter_by_completeness([User.t()], non_neg_integer()) :: [User.t()]
  def filter_by_completeness(users, min_percentage) when is_list(users) and is_integer(min_percentage) do
    Enum.filter(users, fn user ->
      completeness_percentage(user) >= min_percentage
    end)
  end

  @doc """
  Groups users by their profile completeness ranges.
  
  ## Examples
  
      iex> Zonely.UserProfile.group_by_completeness(users)
      %{
        complete: [user1],      # 90-100%
        mostly_complete: [user2], # 70-89%
        incomplete: [user3]     # <70%
      }
  """
  @spec group_by_completeness([User.t()]) :: %{
    complete: [User.t()],
    mostly_complete: [User.t()],
    incomplete: [User.t()]
  }
  def group_by_completeness(users) when is_list(users) do
    grouped = Enum.group_by(users, fn user ->
      case completeness_percentage(user) do
        percentage when percentage >= 90 -> :complete
        percentage when percentage >= 70 -> :mostly_complete
        _ -> :incomplete
      end
    end)
    
    %{
      complete: Map.get(grouped, :complete, []),
      mostly_complete: Map.get(grouped, :mostly_complete, []),
      incomplete: Map.get(grouped, :incomplete, [])
    }
  end

  @doc """
  Gets users with incomplete profiles that need attention.
  
  ## Examples
  
      iex> Zonely.UserProfile.needs_profile_completion(users)
      [%User{name: "Incomplete User"}]
  """
  @spec needs_profile_completion([User.t()]) :: [User.t()]
  def needs_profile_completion(users) when is_list(users) do
    filter_by_completeness(users, 0)
    |> Enum.filter(fn user -> completeness_percentage(user) < 70 end)
  end

  @doc """
  Gets profile statistics for a list of users.
  
  ## Examples
  
      iex> Zonely.UserProfile.get_statistics(users)
      %{
        total_users: 10,
        avg_completeness: 78,
        complete_profiles: 3,
        incomplete_profiles: 2,
        has_native_names: 4
      }
  """
  @spec get_statistics([User.t()]) :: %{
    total_users: non_neg_integer(),
    avg_completeness: non_neg_integer(),
    complete_profiles: non_neg_integer(),
    incomplete_profiles: non_neg_integer(),
    has_native_names: non_neg_integer()
  }
  def get_statistics(users) when is_list(users) do
    completeness_values = Enum.map(users, &completeness_percentage/1)
    avg_completeness = if length(completeness_values) > 0 do
      Enum.sum(completeness_values) |> div(length(completeness_values))
    else
      0
    end
    
    %{
      total_users: length(users),
      avg_completeness: avg_completeness,
      complete_profiles: length(filter_by_completeness(users, 90)),
      incomplete_profiles: length(needs_profile_completion(users)),
      has_native_names: Enum.count(users, &has_different_native_name?/1)
    }
  end

  @doc """
  Gets initials from a user's name for display purposes.
  
  ## Examples
  
      iex> user = %User{name: "John Doe"}
      iex> Zonely.UserProfile.initials(user)
      "JD"
  """
  @spec initials(User.t()) :: String.t()
  def initials(%User{name: name}) do
    AvatarService.generate_initials_avatar(name).initials
  end

  @doc """
  Checks if user profile is considered complete for business purposes.
  
  ## Examples
  
      iex> Zonely.UserProfile.profile_complete?(user)
      true
  """
  @spec profile_complete?(User.t()) :: boolean()
  def profile_complete?(%User{} = user) do
    completeness_percentage(user) >= 90
  end

  @doc """
  Gets validation errors for a user profile.
  
  ## Examples
  
      iex> Zonely.UserProfile.validation_errors(user)
      ["Missing work hours", "Invalid timezone"]
  """
  @spec validation_errors(User.t()) :: [String.t()]
  def validation_errors(%User{} = user) do
    errors = []
    
    errors = if !field_filled?(user, :name), do: ["Name is required" | errors], else: errors
    errors = if !field_filled?(user, :role), do: ["Role is required" | errors], else: errors
    errors = if !field_filled?(user, :timezone), do: ["Timezone is required" | errors], else: errors
    errors = if !field_filled?(user, :country), do: ["Country is required" | errors], else: errors
    
    errors = if user.timezone && !Geography.valid_timezone?(user.timezone) do
      ["Invalid timezone format" | errors]
    else
      errors
    end
    
    errors = if user.country && !Geography.valid_country?(user.country) do
      ["Invalid country code" | errors]
    else
      errors
    end
    
    Enum.reverse(errors)
  end
end