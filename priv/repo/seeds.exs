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
    phonetic: "AL-iss CHEN",
    name_native: "Alice Chen",
    phonetic_native: "AL-iss CHEN", 
    native_language: "en-US",
    pronouns: "she/her",
    role: "Frontend Developer",
    timezone: "America/Los_Angeles",
    country: "US",
    work_start: ~T[09:00:00],
    work_end: ~T[17:00:00]
  },
  %{
    name: "Björn Eriksson",
    phonetic: "bee-YORN air-ick-son",
    name_native: "Björn Eriksson",
    phonetic_native: "björn eriksson",
    native_language: "sv-SE",
    pronouns: "he/him",
    role: "Backend Engineer",
    timezone: "Europe/Stockholm",
    country: "SE",
    work_start: ~T[08:00:00],
    work_end: ~T[16:00:00]
  },
  %{
    name: "Priya Sharma",
    phonetic: "PREE-ya SHAR-ma",
    name_native: "प्रिया शर्मा",
    phonetic_native: "priya sharma",
    native_language: "hi-IN",
    pronouns: "she/her",
    role: "Product Manager",
    timezone: "Asia/Kolkata",
    country: "IN",
    work_start: ~T[10:00:00],
    work_end: ~T[18:00:00]
  },
  %{
    name: "James Wilson",
    phonetic: "JAYMZ WIL-son",
    name_native: "James Wilson",
    phonetic_native: "JAYMZ WIL-son",
    native_language: "en-US",
    pronouns: "he/him",
    role: "DevOps Engineer",
    timezone: "America/New_York",
    country: "US",
    work_start: ~T[08:30:00],
    work_end: ~T[16:30:00]
  },
  %{
    name: "Yuki Tanaka",
    phonetic: "YOO-kee ta-NAH-ka",
    name_native: "田中雪",
    phonetic_native: "tanaka yuki",
    native_language: "ja-JP",
    pronouns: "they/them",
    role: "UX Designer",
    timezone: "Asia/Tokyo",
    country: "JP",
    work_start: ~T[09:30:00],
    work_end: ~T[17:30:00]
  },
  %{
    name: "Maria García",
    phonetic: "ma-REE-a gar-SEE-a",
    name_native: "María García",
    phonetic_native: "maría garcía",
    native_language: "es-ES",
    pronouns: "she/her",
    role: "Data Scientist",
    timezone: "Europe/Madrid",
    country: "ES",
    work_start: ~T[09:00:00],
    work_end: ~T[17:00:00]
  },
  %{
    name: "David Kim",
    phonetic: "DAY-vid KIM",
    name_native: "David Kim",
    phonetic_native: "DAY-vid KIM",
    native_language: "en-AU",
    pronouns: "he/him",
    role: "Engineering Manager",
    timezone: "Australia/Sydney",
    country: "AU",
    work_start: ~T[09:00:00],
    work_end: ~T[17:00:00]
  },
  %{
    name: "Sarah O'Connor",
    phonetic: "SAIR-a oh-CON-or",
    name_native: "Sarah O'Connor",
    phonetic_native: "SAIR-a oh-CON-or",
    native_language: "en-GB",
    pronouns: "she/her",
    role: "QA Engineer",
    timezone: "Europe/London",
    country: "GB",
    work_start: ~T[08:00:00],
    work_end: ~T[16:00:00]
  },
  %{
    name: "Ahmed Hassan",
    phonetic: "AH-med ha-SAHN",
    name_native: "أحمد حسن",
    phonetic_native: "ahmed hassan",
    native_language: "ar-EG",
    pronouns: "he/him",
    role: "Security Engineer",
    timezone: "Africa/Cairo",
    country: "EG",
    work_start: ~T[09:00:00],
    work_end: ~T[17:00:00]
  },
  %{
    name: "Luiza Santos",
    phonetic: "loo-EE-za SAHN-tos",
    name_native: "Luiza Santos",
    phonetic_native: "luiza santos",
    native_language: "pt-BR",
    pronouns: "she/her",
    role: "Full Stack Developer",
    timezone: "America/Sao_Paulo",
    country: "BR",
    work_start: ~T[08:00:00],
    work_end: ~T[16:00:00]
  }
]

IO.puts("Creating users...")

for user_attrs <- users do
  user = %User{}
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
  holiday = %Holiday{}
  |> Holiday.changeset(holiday_attrs)
  |> Repo.insert!()
  
  IO.puts("  ✓ Created holiday: #{holiday.name} (#{holiday.country})")
end

IO.puts("Seeding completed!")
IO.puts("Created #{length(users)} users and #{length(holidays)} holidays.")