defmodule ZonelyWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for Zonely.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders the Zonely logo with consistent styling.
  """
  attr :class, :string, default: "", doc: "additional CSS classes"
  attr :link, :boolean, default: true, doc: "whether to wrap in a link to home"

  def logo(assigns) do
    ~H"""
    <div class={["flex items-center gap-3", @class]}>
      <div class="relative h-8 w-8">
        <!-- Outer ring for contrast on any background -->
        <div class="absolute inset-0 rounded-full bg-slate-600 shadow-sm"></div>
        <!-- Inner clock face with subtle transparency -->
        <div class="absolute inset-1 rounded-full bg-white/90 backdrop-blur-sm flex items-center justify-center">
          <!-- Clock hands representing different timezones -->
          <div class="absolute inset-0">
            <!-- Hour hand -->
            <div class="absolute top-1/2 left-1/2 w-1.5 h-px bg-slate-600 origin-left transform -translate-x-0.5 -translate-y-px rotate-45"></div>
            <!-- Minute hand -->
            <div class="absolute top-1/2 left-1/2 w-2 h-px bg-slate-500 origin-left transform -translate-x-0.5 -translate-y-px -rotate-12"></div>
          </div>
          <!-- Center dot -->
          <div class="w-0.5 h-0.5 bg-slate-700 rounded-full z-10"></div>
        </div>
      </div>
      <span class="text-xl font-medium text-slate-700 tracking-tight">Zonely</span>
    </div>
    """
  end

  @doc """
  Renders the Zonely logo with a link to home.
  """
  attr :class, :string, default: "", doc: "additional CSS classes"

  def logo_link(assigns) do
    ~H"""
    <a href="/" class={@class}>
      <.logo />
    </a>
    """
  end

  @doc """
  Renders flash notices.
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        <%= @title %>
      </p>
      <p class="mt-2 text-sm leading-5"><%= msg %></p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label="close">
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
    </div>
    """
  end

  @doc """
  Renders an input with label and error messages.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search tel text textarea time url week select)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "min-h-[6rem] phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div>
      <.label for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders an icon.
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## Helpers

  defp hide(js, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  defp translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(ZonelyWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(ZonelyWeb.Gettext, "errors", msg, opts)
    end
  end

  defp translate_error(msg) do
    Gettext.dgettext(ZonelyWeb.Gettext, "errors", msg)
  end

  @doc """
  Renders an inline actions popup with expandable action forms.
  """
  attr :user, :map, required: true
  attr :class, :string, default: ""
  attr :expanded_action, :string, default: nil

  def inline_actions_popup(assigns) do
    ~H"""
    <div class={["bg-white rounded-lg shadow-lg border border-gray-200 p-4 w-72", @class]}>
      <!-- User Info Header -->
      <div class="flex items-center gap-3 mb-4 pb-3 border-b border-gray-100">
        <img
          src={user_avatar_url(@user.name)}
          alt={"#{@user.name}'s avatar"}
          class="w-10 h-10 rounded-full"
        />
        <div class="flex-1 min-w-0">
          <h3 class="font-medium text-gray-900 truncate"><%= @user.name %></h3>
          <p class="text-sm text-gray-500"><%= @user.timezone %></p>
        </div>
        <div class="flex flex-col items-end">
          <div class="text-xs text-gray-500">Local Time</div>
          <div class="font-medium text-gray-900">2:30 PM</div>
        </div>
      </div>

      <!-- Status & Availability -->
      <div class="mb-4 flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div class="w-2 h-2 bg-green-400 rounded-full"></div>
          <span class="text-sm text-gray-600">Available</span>
        </div>
        <div class="text-xs text-gray-500">Working hours</div>
      </div>

      <!-- Phase 1 Actions -->
      <div class="space-y-2 mb-4">
        <h4 class="text-xs font-medium text-gray-500 uppercase tracking-wide">Quick Actions</h4>

        <!-- Message Action -->
        <.action_pill
          icon="💬"
          label="Message"
          action="message"
          expanded={@expanded_action == "message"}
          user={@user}
        />

        <!-- Propose Meeting Action -->
        <.action_pill
          icon="📅"
          label="Propose Meeting"
          action="propose_meeting"
          expanded={@expanded_action == "propose_meeting"}
          user={@user}
        />

        <!-- Pin Timezone Action -->
        <.action_pill
          icon="📌"
          label="Pin Timezone"
          action="pin_timezone"
          expanded={@expanded_action == "pin_timezone"}
          user={@user}
        />
      </div>

      <!-- Phase 2 Actions -->
      <div class="space-y-2 mb-4">
        <h4 class="text-xs font-medium text-gray-500 uppercase tracking-wide">Schedule</h4>

        <!-- Reminder Action -->
        <.action_pill
          icon="⏰"
          label="Set Reminder"
          action="reminder"
          expanded={@expanded_action == "reminder"}
          user={@user}
        />

        <!-- Notify Team Action -->
        <.action_pill
          icon="🔔"
          label="Notify Team"
          action="notify_team"
          expanded={@expanded_action == "notify_team"}
          user={@user}
        />

        <!-- Quick Status Action -->
        <.action_pill
          icon="✅"
          label="Update Status"
          action="quick_status"
          expanded={@expanded_action == "quick_status"}
          user={@user}
        />
      </div>

      <!-- Phase 3 Actions -->
      <div class="space-y-2">
        <h4 class="text-xs font-medium text-gray-500 uppercase tracking-wide">Collaborate</h4>

        <!-- Whiteboard Action -->
        <.action_pill
          icon="🎨"
          label="Share Whiteboard"
          action="whiteboard"
          expanded={@expanded_action == "whiteboard"}
          user={@user}
        />

        <!-- Quick Poll Action -->
        <.action_pill
          icon="📊"
          label="Quick Poll"
          action="quick_poll"
          expanded={@expanded_action == "quick_poll"}
          user={@user}
        />

        <!-- Share Doc Action -->
        <.action_pill
          icon="📄"
          label="Share Document"
          action="share_doc"
          expanded={@expanded_action == "share_doc"}
          user={@user}
        />
      </div>
    </div>
    """
  end

  @doc """
  Renders an individual action pill that can expand into an inline form.
  """
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :action, :string, required: true
  attr :expanded, :boolean, default: false
  attr :user, :map, required: true

  def action_pill(assigns) do
    ~H"""
    <div class="group">
      <!-- Action Button -->
      <button
        phx-click="toggle_action"
        phx-value-action={@action}
        phx-value-user_id={@user.id}
        class={[
          "w-full flex items-center gap-3 px-3 py-2 rounded-md transition-all duration-200",
          "hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-1",
          @expanded && "bg-blue-50 text-blue-700",
          !@expanded && "text-gray-700 hover:text-gray-900"
        ]}
      >
        <span class="text-base"><%= @icon %></span>
        <span class="text-sm font-medium flex-1 text-left"><%= @label %></span>
        <.icon
          name={if @expanded, do: "hero-chevron-up", else: "hero-chevron-right"}
          class="w-4 h-4 transition-transform duration-200"
        />
      </button>

      <!-- Expanded Form -->
      <div :if={@expanded} class="mt-2 pl-9 pr-3 pb-3">
        <.action_form action={@action} user={@user} />
      </div>
    </div>
    """
  end

  @doc """
  Renders the appropriate inline form based on the action type.
  """
  attr :action, :string, required: true
  attr :user, :map, required: true

  def action_form(%{action: "message"} = assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="flex gap-2">
        <button class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded hover:bg-blue-200">
          Slack
        </button>
        <button class="px-2 py-1 text-xs font-medium bg-gray-100 text-gray-700 rounded hover:bg-gray-200">
          Teams
        </button>
        <button class="px-2 py-1 text-xs font-medium bg-gray-100 text-gray-700 rounded hover:bg-gray-200">
          Email
        </button>
      </div>
      <textarea
        placeholder={"Message #{@user.name}..."}
        class="w-full p-2 text-sm border border-gray-200 rounded-md resize-none focus:outline-none focus:ring-2 focus:ring-blue-500"
        rows="3"
      />
      <div class="flex justify-end gap-2">
        <button
          phx-click="cancel_action"
          class="px-3 py-1 text-xs font-medium text-gray-600 hover:text-gray-800"
        >
          Cancel
        </button>
        <button
          phx-click="send_message"
          phx-value-user_id={@user.id}
          class="px-3 py-1 text-xs font-medium bg-blue-600 text-white rounded hover:bg-blue-700"
        >
          Send
        </button>
      </div>
    </div>
    """
  end

  def action_form(%{action: "propose_meeting"} = assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="grid grid-cols-2 gap-2">
        <input
          type="date"
          class="p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
        <input
          type="time"
          class="p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
      <div class="grid grid-cols-2 gap-2">
        <select class="p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option>30 min</option>
          <option>1 hour</option>
          <option>1.5 hours</option>
          <option>2 hours</option>
        </select>
        <select class="p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option>Zoom</option>
          <option>Meet</option>
          <option>Teams</option>
          <option>In-person</option>
        </select>
      </div>
      <input
        type="text"
        placeholder="Meeting title"
        class="w-full p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
      <div class="flex justify-end gap-2">
        <button
          phx-click="cancel_action"
          class="px-3 py-1 text-xs font-medium text-gray-600 hover:text-gray-800"
        >
          Cancel
        </button>
        <button
          phx-click="propose_meeting"
          phx-value-user_id={@user.id}
          class="px-3 py-1 text-xs font-medium bg-green-600 text-white rounded hover:bg-green-700"
        >
          Propose
        </button>
      </div>
    </div>
    """
  end

  def action_form(%{action: "pin_timezone"} = assigns) do
    ~H"""
    <div class="space-y-3">
      <p class="text-sm text-gray-600">
        Add <%= @user.name %>'s timezone (<%= @user.timezone %>) to your favorites bar?
      </p>
      <div class="flex justify-end gap-2">
        <button
          phx-click="cancel_action"
          class="px-3 py-1 text-xs font-medium text-gray-600 hover:text-gray-800"
        >
          Cancel
        </button>
        <button
          phx-click="pin_timezone"
          phx-value-user_id={@user.id}
          class="px-3 py-1 text-xs font-medium bg-yellow-600 text-white rounded hover:bg-yellow-700"
        >
          Pin Timezone
        </button>
      </div>
    </div>
    """
  end

  def action_form(%{action: "reminder"} = assigns) do
    ~H"""
    <div class="space-y-3">
      <select class="w-full p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500">
        <option>When <%= @user.name %> starts working tomorrow</option>
        <option>When <%= @user.name %> comes online</option>
        <option>30 minutes before <%= @user.name %>'s working hours</option>
        <option>Custom time...</option>
      </select>
      <div class="flex justify-end gap-2">
        <button
          phx-click="cancel_action"
          class="px-3 py-1 text-xs font-medium text-gray-600 hover:text-gray-800"
        >
          Cancel
        </button>
        <button
          phx-click="set_reminder"
          phx-value-user_id={@user.id}
          class="px-3 py-1 text-xs font-medium bg-purple-600 text-white rounded hover:bg-purple-700"
        >
          Set Reminder
        </button>
      </div>
    </div>
    """
  end

  def action_form(%{action: "notify_team"} = assigns) do
    ~H"""
    <div class="space-y-3">
      <select class="w-full p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500">
        <option>Working hours overlap in 2 hours</option>
        <option>All hands meeting reminder</option>
        <option>Timezone change notification</option>
        <option>Custom notification...</option>
      </select>
      <div class="flex justify-end gap-2">
        <button
          phx-click="cancel_action"
          class="px-3 py-1 text-xs font-medium text-gray-600 hover:text-gray-800"
        >
          Cancel
        </button>
        <button
          phx-click="notify_team"
          phx-value-user_id={@user.id}
          class="px-3 py-1 text-xs font-medium bg-orange-600 text-white rounded hover:bg-orange-700"
        >
          Notify
        </button>
      </div>
    </div>
    """
  end

  def action_form(%{action: "quick_status"} = assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="grid grid-cols-2 gap-2">
        <button class="p-2 text-sm border border-gray-200 rounded hover:bg-green-50 hover:border-green-300">
          🟢 Available
        </button>
        <button class="p-2 text-sm border border-gray-200 rounded hover:bg-yellow-50 hover:border-yellow-300">
          🟡 Busy
        </button>
        <button class="p-2 text-sm border border-gray-200 rounded hover:bg-red-50 hover:border-red-300">
          🔴 Do Not Disturb
        </button>
        <button class="p-2 text-sm border border-gray-200 rounded hover:bg-gray-50 hover:border-gray-300">
          ⚫ Away
        </button>
      </div>
      <input
        type="text"
        placeholder="Status message (optional)"
        class="w-full p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
      <div class="flex justify-end gap-2">
        <button
          phx-click="cancel_action"
          class="px-3 py-1 text-xs font-medium text-gray-600 hover:text-gray-800"
        >
          Cancel
        </button>
        <button
          phx-click="update_status"
          phx-value-user_id={@user.id}
          class="px-3 py-1 text-xs font-medium bg-indigo-600 text-white rounded hover:bg-indigo-700"
        >
          Update
        </button>
      </div>
    </div>
    """
  end

  def action_form(%{action: "whiteboard"} = assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="flex gap-2">
        <button class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded hover:bg-blue-200">
          Miro
        </button>
        <button class="px-2 py-1 text-xs font-medium bg-gray-100 text-gray-700 rounded hover:bg-gray-200">
          Figma
        </button>
        <button class="px-2 py-1 text-xs font-medium bg-gray-100 text-gray-700 rounded hover:bg-gray-200">
          Excalidraw
        </button>
      </div>
      <input
        type="text"
        placeholder="Whiteboard title"
        class="w-full p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
      <div class="flex justify-end gap-2">
        <button
          phx-click="cancel_action"
          class="px-3 py-1 text-xs font-medium text-gray-600 hover:text-gray-800"
        >
          Cancel
        </button>
        <button
          phx-click="create_whiteboard"
          phx-value-user_id={@user.id}
          class="px-3 py-1 text-xs font-medium bg-pink-600 text-white rounded hover:bg-pink-700"
        >
          Create & Share
        </button>
      </div>
    </div>
    """
  end

  def action_form(%{action: "quick_poll"} = assigns) do
    ~H"""
    <div class="space-y-3">
      <input
        type="text"
        placeholder="Poll question"
        class="w-full p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
      <div class="space-y-1">
        <input
          type="text"
          placeholder="Option 1"
          class="w-full p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
        <input
          type="text"
          placeholder="Option 2"
          class="w-full p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
      <div class="flex justify-end gap-2">
        <button
          phx-click="cancel_action"
          class="px-3 py-1 text-xs font-medium text-gray-600 hover:text-gray-800"
        >
          Cancel
        </button>
        <button
          phx-click="create_poll"
          phx-value-user_id={@user.id}
          class="px-3 py-1 text-xs font-medium bg-cyan-600 text-white rounded hover:bg-cyan-700"
        >
          Create Poll
        </button>
      </div>
    </div>
    """
  end

  def action_form(%{action: "share_doc"} = assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="flex gap-2">
        <button class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded hover:bg-blue-200">
          Google Docs
        </button>
        <button class="px-2 py-1 text-xs font-medium bg-gray-100 text-gray-700 rounded hover:bg-gray-200">
          Notion
        </button>
        <button class="px-2 py-1 text-xs font-medium bg-gray-100 text-gray-700 rounded hover:bg-gray-200">
          Link
        </button>
      </div>
      <input
        type="text"
        placeholder="Document title or URL"
        class="w-full p-2 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
      <div class="flex justify-end gap-2">
        <button
          phx-click="cancel_action"
          class="px-3 py-1 text-xs font-medium text-gray-600 hover:text-gray-800"
        >
          Cancel
        </button>
        <button
          phx-click="share_document"
          phx-value-user_id={@user.id}
          class="px-3 py-1 text-xs font-medium bg-teal-600 text-white rounded hover:bg-teal-700"
        >
          Share
        </button>
      </div>
    </div>
    """
  end

  # Fallback for unknown actions
  def action_form(assigns) do
    ~H"""
    <div class="text-sm text-gray-500 italic">
      Action form for "<%= @action %>" not implemented yet.
    </div>
    """
  end

  @doc """
  Renders compact quick action icons for map popup.
  """
  attr :user, :map, required: true
  attr :expanded_action, :string, default: nil

  def quick_actions_bar(assigns) do
    ~H"""
    <div class="border-t border-gray-100 pt-3 mt-3">
      <div class="flex items-center justify-between mb-2">
        <h4 class="text-sm font-medium text-gray-700">Quick Actions</h4>
        <div class="flex gap-1">
          <!-- Message -->
          <button
            phx-click="toggle_quick_action"
            phx-value-action="message"
            phx-value-user_id={@user.id}
            class={[
              "p-2 rounded-md transition-colors text-sm",
              @expanded_action == "message" && "bg-blue-100 text-blue-700",
              @expanded_action != "message" && "hover:bg-gray-100 text-gray-600"
            ]}
            title="Send message"
          >
            💬
          </button>

          <!-- Meeting -->
          <button
            phx-click="toggle_quick_action"
            phx-value-action="meeting"
            phx-value-user_id={@user.id}
            class={[
              "p-2 rounded-md transition-colors text-sm",
              @expanded_action == "meeting" && "bg-green-100 text-green-700",
              @expanded_action != "meeting" && "hover:bg-gray-100 text-gray-600"
            ]}
            title="Propose meeting"
          >
            📅
          </button>

          <!-- Pin Timezone -->
          <button
            phx-click="quick_pin"
            phx-value-user_id={@user.id}
            class="p-2 rounded-md hover:bg-yellow-100 text-gray-600 hover:text-yellow-700 transition-colors text-sm"
            title="Pin timezone"
          >
            📌
          </button>
        </div>
      </div>

      <!-- Expanded Quick Forms -->
      <div :if={@expanded_action} class="mt-2">
        <.quick_action_form action={@expanded_action} user={@user} />
      </div>
    </div>
    """
  end

  @doc """
  Renders compact inline forms for quick actions.
  """
  attr :action, :string, required: true
  attr :user, :map, required: true

  def quick_action_form(%{action: "message"} = assigns) do
    ~H"""
    <div class="bg-gray-50 rounded-md p-3 space-y-2">
      <div class="flex gap-1">
        <button class="px-2 py-1 text-xs bg-blue-100 text-blue-700 rounded">Slack</button>
        <button class="px-2 py-1 text-xs bg-gray-200 text-gray-700 rounded">Teams</button>
        <button class="px-2 py-1 text-xs bg-gray-200 text-gray-700 rounded">Email</button>
      </div>
      <textarea
        placeholder={"Quick message to #{@user.name}..."}
        class="w-full p-2 text-xs border border-gray-200 rounded resize-none"
        rows="2"
      />
      <div class="flex justify-end gap-1">
        <button
          phx-click="cancel_quick_action"
          class="px-2 py-1 text-xs text-gray-600 hover:text-gray-800"
        >
          Cancel
        </button>
        <button
          phx-click="quick_message"
          phx-value-user_id={@user.id}
          class="px-2 py-1 text-xs bg-blue-600 text-white rounded hover:bg-blue-700"
        >
          Send
        </button>
      </div>
    </div>
    """
  end

  def quick_action_form(%{action: "meeting"} = assigns) do
    ~H"""
    <div class="bg-gray-50 rounded-md p-3 space-y-2">
      <div class="grid grid-cols-2 gap-2">
        <input
          type="time"
          class="p-1 text-xs border border-gray-200 rounded"
          value="14:00"
        />
        <select class="p-1 text-xs border border-gray-200 rounded">
          <option>30 min</option>
          <option>1 hour</option>
        </select>
      </div>
      <input
        type="text"
        placeholder="Quick sync"
        class="w-full p-1 text-xs border border-gray-200 rounded"
      />
      <div class="flex justify-end gap-1">
        <button
          phx-click="cancel_quick_action"
          class="px-2 py-1 text-xs text-gray-600 hover:text-gray-800"
        >
          Cancel
        </button>
        <button
          phx-click="quick_meeting"
          phx-value-user_id={@user.id}
          class="px-2 py-1 text-xs bg-green-600 text-white rounded hover:bg-green-700"
        >
          Propose
        </button>
      </div>
    </div>
    """
  end

  # Fallback for unknown quick actions
  def quick_action_form(assigns) do
    ~H"""
    <div class="text-xs text-gray-500 italic">
      Quick action form not implemented yet.
    </div>
    """
  end

  defp user_avatar_url(name) do
    seed = name |> String.downcase() |> String.replace(" ", "-")
    "https://api.dicebear.com/7.x/avataaars/svg?seed=#{seed}&backgroundColor=b6e3f4,c0aede,d1d4f9&size=64"
  end
 
  @doc """
  Renders the Map Legend used on the map pages.
  """
  def map_legend(assigns) do
    ~H"""
    <div class="fixed top-20 right-4 z-20 bg-white/90 backdrop-blur-sm rounded-lg shadow-lg p-3 max-w-xs">
      <div class="text-sm font-semibold text-gray-900 mb-2">Map Overlays</div>

      <div class="mb-3 pb-2 border-b border-gray-200">
        <div class="flex items-center gap-2 mb-1">
          <div class="w-3 h-3 rounded" style="background-color: #1a1a2e;"></div>
          <span class="text-xs font-medium text-gray-700">Night Region</span>
        </div>
        <div class="text-xs text-gray-500 ml-5">Live day/night boundary</div>
      </div>

      <div class="text-xs font-semibold text-gray-900 mb-1">Timezone Regions</div>
      <div class="space-y-1 text-xs">
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded" style="background-color: rgba(255, 99, 132, 0.6);"></div>
          <span class="text-gray-700">Pacific Time (UTC-8)</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded" style="background-color: rgba(54, 162, 235, 0.6);"></div>
          <span class="text-gray-700">Mountain Time (UTC-7)</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded" style="background-color: rgba(255, 205, 86, 0.6);"></div>
          <span class="text-gray-700">Central Time (UTC-6)</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded" style="background-color: rgba(75, 192, 192, 0.6);"></div>
          <span class="text-gray-700">Eastern Time (UTC-5)</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded" style="background-color: rgba(153, 102, 255, 0.6);"></div>
          <span class="text-gray-700">European Time (UTC+0 to +2)</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded" style="background-color: rgba(255, 159, 64, 0.6);"></div>
          <span class="text-gray-700">Asian Time (UTC+3 to +10)</span>
        </div>
      </div>
    </div>
    """
  end
end
