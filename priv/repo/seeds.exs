# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Zonely.Repo.insert!(%Zonely.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Zonely.Repo
alias Zonely.Accounts.User
alias Zonely.Holidays.Holiday

# Clear existing data
Repo.delete_all(Holiday)
Repo.delete_all(User)

# Seed users from different countries and timezones
users = [
  %{
    name: "Alice Chen",
    name_native: "Alice Chen",
    native_language: "en-US",
    pronouns: "she/her",
    role: "Frontend Developer",
    timezone: "America/Los_Angeles",
    country: "US",
    work_start: ~T[09:00:00],
    work_end: ~T[17:00:00],
    latitude: 37.7749,
    longitude: -122.4194
  },
  %{
    name: "Qingbo Zhang",
    name_native: "张清波",
    native_language: "zh-CN",
    pronouns: "he/him",
    role: "Tech Lead",
    timezone: "Asia/Shanghai",
    country: "CN",
    work_start: ~T[09:00:00],
    work_end: ~T[18:00:00],
    latitude: 34.274342,
    longitude: 108.889191
  },
  %{
    name: "Björn Eriksson",
    name_native: "Björn Eriksson",
    native_language: "sv-SE",
    pronouns: "he/him",
    role: "Backend Engineer",
    timezone: "Europe/Stockholm",
    country: "SE",
    work_start: ~T[08:00:00],
    work_end: ~T[16:00:00],
    latitude: 59.3293,
    longitude: 18.0686
  },
  %{
    name: "Priya Sharma",
    name_native: "प्रिया शर्मा",
    native_language: "hi-IN",
    pronouns: "she/her",
    role: "Product Manager",
    timezone: "Asia/Kolkata",
    country: "IN",
    work_start: ~T[10:00:00],
    work_end: ~T[18:00:00],
    latitude: 28.7041,
    longitude: 77.1025
  },
  %{
    name: "James Wilson",
    name_native: "James Wilson",
    native_language: "en-US",
    pronouns: "he/him",
    role: "DevOps Engineer",
    timezone: "America/New_York",
    country: "US",
    work_start: ~T[08:30:00],
    work_end: ~T[16:30:00],
    latitude: 40.7128,
    longitude: -74.0060
  },
  %{
    name: "Yuki Tanaka",
    name_native: "田中雪",
    native_language: "ja-JP",
    pronouns: "they/them",
    role: "UX Designer",
    timezone: "Asia/Tokyo",
    country: "JP",
    work_start: ~T[09:30:00],
    work_end: ~T[17:30:00],
    latitude: 35.6762,
    longitude: 139.6503
  },
  %{
    name: "María García",
    name_native: "María García",
    native_language: "es-ES",
    pronouns: "she/her",
    role: "Data Scientist",
    timezone: "Europe/Madrid",
    country: "ES",
    work_start: ~T[09:00:00],
    work_end: ~T[17:00:00],
    latitude: 40.4168,
    longitude: -3.7038
  },
  %{
    name: "David Kim",
    name_native: "David Kim",
    native_language: "en-AU",
    pronouns: "he/him",
    role: "Engineering Manager",
    timezone: "Australia/Sydney",
    country: "AU",
    work_start: ~T[09:00:00],
    work_end: ~T[17:00:00],
    latitude: -33.8688,
    longitude: 151.2093
  },
  %{
    name: "Sarah O'Connor",
    name_native: "Sarah O'Connor",
    native_language: "en-GB",
    pronouns: "she/her",
    role: "QA Engineer",
    timezone: "Europe/London",
    country: "GB",
    work_start: ~T[08:00:00],
    work_end: ~T[16:00:00],
    latitude: 51.5074,
    longitude: -0.1278
  },
  %{
    name: "Ahmed Hassan",
    name_native: "أحمد حسن",
    native_language: "ar-EG",
    pronouns: "he/him",
    role: "Security Engineer",
    timezone: "Africa/Cairo",
    country: "EG",
    work_start: ~T[09:00:00],
    work_end: ~T[17:00:00],
    latitude: 30.0444,
    longitude: 31.2357
  },
  %{
    name: "Luiza Santos",
    name_native: "Luiza Santos",
    native_language: "pt-BR",
    pronouns: "she/her",
    role: "Full Stack Developer",
    timezone: "America/Sao_Paulo",
    country: "BR",
    work_start: ~T[08:00:00],
    work_end: ~T[16:00:00],
    latitude: -23.5505,
    longitude: -46.6333
  }
]

IO.puts("Creating users...")

for user_attrs <- users do
  user =
    %User{}
    |> User.changeset(user_attrs)
    |> Repo.insert!()

  IO.puts("  ✓ Created user: #{user.name}")
end

# Seed some sample holidays
holidays = [
  %{
    country: "US",
    date: ~D[2025-01-01],
    name: "New Year's Day"
  },
  %{
    country: "US",
    date: ~D[2025-01-20],
    name: "Martin Luther King Jr. Day"
  },
  %{
    country: "US",
    date: ~D[2025-02-17],
    name: "Presidents' Day"
  },
  %{
    country: "GB",
    date: ~D[2025-01-01],
    name: "New Year's Day"
  },
  %{
    country: "GB",
    date: ~D[2025-04-18],
    name: "Good Friday"
  },
  %{
    country: "GB",
    date: ~D[2025-04-21],
    name: "Easter Monday"
  },
  %{
    country: "JP",
    date: ~D[2025-01-01],
    name: "New Year's Day"
  },
  %{
    country: "JP",
    date: ~D[2025-01-13],
    name: "Coming of Age Day"
  },
  %{
    country: "JP",
    date: ~D[2025-02-11],
    name: "National Foundation Day"
  },
  %{
    country: "IN",
    date: ~D[2025-01-26],
    name: "Republic Day"
  },
  %{
    country: "IN",
    date: ~D[2025-08-15],
    name: "Independence Day"
  },
  %{
    country: "IN",
    date: ~D[2025-10-02],
    name: "Gandhi Jayanti"
  }
]

IO.puts("Creating holidays...")

for holiday_attrs <- holidays do
  holiday =
    %Holiday{}
    |> Holiday.changeset(holiday_attrs)
    |> Repo.insert!()

  IO.puts("  ✓ Created holiday: #{holiday.name} (#{holiday.country})")
end

IO.puts("Seeding completed!")
IO.puts("Created #{length(users)} users and #{length(holidays)} holidays.")
