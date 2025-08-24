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
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

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
  Renders the main navigation bar with mobile support.
  """
  attr :current_page, :string, default: "map", doc: "the currently active page"
  attr :page_title, :string, default: "Global Team Map", doc: "the page title to display"

  def navbar(assigns) do
    ~H"""
    <header class="fixed top-0 left-0 right-0 z-[1000] pointer-events-auto bg-white/95 backdrop-blur-sm border-b border-gray-200">
      <div class="flex items-center justify-between px-4 py-3">
        <div class="flex items-center gap-4">
          <.logo_link class="flex items-center gap-2" />
          <h1 class="text-lg font-semibold text-gray-700 hidden sm:block"><%= @page_title %></h1>
        </div>

        <!-- Desktop Navigation -->
        <nav class="hidden lg:flex items-center gap-1">
          <.nav_link navigate="/" current={@current_page == "map"}>Map</.nav_link>
          <.nav_link navigate="/directory" current={@current_page == "directory"}>Directory</.nav_link>
          <.nav_link navigate="/work-hours" current={@current_page == "work-hours"}>Work Hours</.nav_link>
          <.nav_link navigate="/holidays" current={@current_page == "holidays"}>Holidays</.nav_link>
        </nav>

        <!-- Mobile Burger Menu Button -->
        <button
          id="mobile-menu-button"
          class="lg:hidden p-2 rounded-md text-gray-700 hover:text-gray-900 hover:bg-gray-100 transition-colors"
          phx-click={JS.toggle(to: "#mobile-menu", display: "block")}
          aria-controls="mobile-menu"
          aria-expanded="false"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
          </svg>
        </button>
      </div>

      <!-- Mobile Navigation Menu -->
      <div
        id="mobile-menu"
        class="lg:hidden block absolute left-0 right-0 top-full mt-1 bg-white border-t border-gray-200 shadow-sm z-[1100]"
        phx-click-away={JS.hide(to: "#mobile-menu")}
      >
        <nav class="flex flex-col space-y-1 px-4 py-2">
          <.mobile_nav_link navigate="/" current={@current_page == "map"}>Map</.mobile_nav_link>
          <.mobile_nav_link navigate="/directory" current={@current_page == "directory"}>Directory</.mobile_nav_link>
          <.mobile_nav_link navigate="/work-hours" current={@current_page == "work-hours"}>Work Hours</.mobile_nav_link>
          <.mobile_nav_link navigate="/holidays" current={@current_page == "holidays"}>Holidays</.mobile_nav_link>
        </nav>
      </div>
    </header>
    """
  end

  @doc """
  Renders a desktop navigation link.
  """
  attr :navigate, :string, required: true
  attr :current, :boolean, default: false
  slot :inner_block, required: true

  def nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "px-3 py-2 text-sm font-medium rounded-md transition-colors",
        @current && "text-blue-700 bg-blue-50",
        !@current && "text-gray-700 hover:bg-gray-100"
      ]}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  @doc """
  Renders a mobile navigation link.
  """
  attr :navigate, :string, required: true
  attr :current, :boolean, default: false
  slot :inner_block, required: true

  def mobile_nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      phx-click={JS.hide(to: "#mobile-menu")}
      class={[
        "px-3 py-3 text-base font-medium rounded-md transition-colors",
        @current && "text-blue-800 bg-blue-50",
        !@current && "text-gray-800 hover:bg-gray-100"
      ]}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
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

  @doc """
  Renders a user avatar with consistent styling and fallback handling.

  Uses AvatarService for avatar generation to maintain consistency across the app.
  """
  attr :user, :map, required: true, doc: "User struct with name"
  attr :size, :integer, default: 64, doc: "Avatar size in pixels"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def user_avatar(assigns) do
    ~H"""
    <img
      src={Zonely.AvatarService.generate_avatar_url(@user.name, @size)}
      alt={"#{@user.name}'s avatar"}
      class={["rounded-full shadow-sm border border-gray-200", @class]}
      style={"width: #{@size}px; height: #{@size}px"}
    />
    """
  end

  @doc """
  Renders pronunciation buttons for a user's name.

  Shows both English and native language pronunciation buttons with proper icons and states.
  """
  attr :user, :map, required: true, doc: "User struct with name, native_language, country"
  attr :size, :atom, default: :normal, values: [:small, :normal, :large], doc: "Button size variant"
  attr :show_labels, :boolean, default: true, doc: "Whether to show language labels"

  def pronunciation_buttons(assigns) do
    # Generate size-specific classes
    assigns = assign(assigns, :size_classes, size_classes_for_pronunciation(assigns.size))

    ~H"""
    <div class="flex items-center gap-1">
      <!-- English pronunciation button -->
      <button
        phx-click="play_english_pronunciation"
        phx-value-user_id={@user.id}
        class={[
          "inline-flex items-center justify-center gap-1 text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded-full transition-colors",
          @size_classes.button
        ]}
        title="Play English pronunciation"
        data-testid="pronunciation-english"
      >
        <svg class={@size_classes.icon} fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"></path>
        </svg>
        <span :if={@show_labels} class={["font-medium", @size_classes.text]}>EN</span>
      </button>

      <!-- Native pronunciation button (if different from English) -->
      <button
        :if={@user.name_native && @user.name_native != @user.name}
        phx-click="play_native_pronunciation"
        phx-value-user_id={@user.id}
        class={[
          "inline-flex items-center justify-center gap-1 text-gray-500 hover:text-emerald-600 hover:bg-emerald-50 rounded-full transition-colors",
          @size_classes.button
        ]}
        title={"Play #{Zonely.LanguageService.get_native_language_name(@user.country)} pronunciation"}
        data-testid="pronunciation-native"
      >
        <svg class={@size_classes.icon} fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"></path>
        </svg>
        <span :if={@show_labels} class={["font-medium", @size_classes.text]}>
          <%= String.slice(Zonely.LanguageService.get_native_language_name(@user.country), 0, 2) |> String.upcase() %>
        </span>
      </button>
    </div>
    """
  end

  @doc """
  Renders timezone and location information for a user.

  Displays country, timezone, and optional local time in a clean, consistent format.
  """
  attr :user, :map, required: true, doc: "User struct with country, timezone"
  attr :show_local_time, :boolean, default: false, doc: "Whether to calculate and show local time"
  attr :layout, :atom, default: :horizontal, values: [:horizontal, :vertical], doc: "Layout direction"

  def timezone_display(assigns) do
    ~H"""
    <div class={[
      "text-sm text-gray-500",
      @layout == :horizontal && "flex items-center justify-between",
      @layout == :vertical && "space-y-1"
    ]}>
      <div class="flex items-center gap-2">
        <span><%= @user.timezone %></span>
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
          <%= @user.country %>
        </span>
      </div>

      <div :if={@show_local_time} class="text-xs font-medium text-gray-700">
        <!-- TODO: Calculate actual local time based on timezone -->
        Local: 2:30 PM
      </div>
    </div>
    """
  end

  @doc """
  Renders working hours information for a user.

  Shows work start/end times with optional status indicator.
  """
  attr :user, :map, required: true, doc: "User struct with work_start, work_end"
  attr :show_status, :boolean, default: false, doc: "Whether to show current availability status"
  attr :compact, :boolean, default: false, doc: "Whether to use compact layout"

  def working_hours(assigns) do
    ~H"""
    <div class={[
      "text-sm",
      @compact && "text-xs"
    ]}>
      <div class="flex items-center gap-2">
        <div :if={@show_status} class="w-2 h-2 bg-green-400 rounded-full"></div>
        <span class="text-gray-700">Working Hours:</span>
      </div>
      <div class={[
        "font-medium text-gray-900 mt-1",
        @compact && "text-xs font-normal"
      ]}>
        <%= Calendar.strftime(@user.work_start, "%I:%M %p") %> -
        <%= Calendar.strftime(@user.work_end, "%I:%M %p") %>
      </div>
      <div :if={@show_status} class={[
        "text-gray-500 mt-1",
        @compact && "text-xs"
      ]}>
        Available now
      </div>
    </div>
    """
  end

  @doc """
  Renders a 24-hour timeline visualization for user work hours.
  """
  attr :users, :list, required: true, doc: "List of users to display on timeline"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def work_hours_timeline(assigns) do
    ~H"""
    <div class={["space-y-3", @class]}>
      <!-- Hours header -->
      <div class="mb-4">
        <div class="grid grid-cols-24 gap-1 text-xs text-gray-500">
          <div :for={hour <- 0..23} class="text-center">
            <%= String.pad_leading(to_string(hour), 2, "0") %>
          </div>
        </div>
      </div>

      <!-- User timelines -->
      <div
        :for={user <- @users}
        class="flex items-center"
      >
        <div class="flex items-center w-40">
          <div class="flex-shrink-0 mr-3">
            <.user_avatar user={user} size={32} />
          </div>
          <div class="text-sm font-medium text-gray-900 truncate">
            <%= user.name %>
          </div>
        </div>
        <div class="flex-1 grid grid-cols-24 gap-1">
          <div
            :for={hour <- 0..23}
            class={[
              "h-6 rounded-sm",
              hour >= user.work_start.hour and hour < user.work_end.hour && "bg-green-200",
              (hour < user.work_start.hour or hour >= user.work_end.hour) && "bg-gray-100"
            ]}
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a holiday card with affected users and time indicators.
  """
  attr :holiday, :map, required: true, doc: "Holiday struct with name, date, country"
  attr :users, :list, required: true, doc: "List of users affected by this holiday"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def holiday_card(assigns) do
    days_until = Zonely.DateUtils.days_until(assigns.holiday.date)
    assigns = assign(assigns, :days_until, days_until)

    ~H"""
    <div class={[
      "flex items-center justify-between p-4 rounded-lg border",
      @days_until <= 7 && "bg-red-50 border-red-200",
      @days_until > 7 && @days_until <= 30 && "bg-yellow-50 border-yellow-200",
      @days_until > 30 && "bg-gray-50 border-gray-200",
      @class
    ]}>
      <div class="flex-1">
        <div class="flex items-center space-x-3">
          <.country_badge country={@holiday.country} />
          <h4 class="text-sm font-medium text-gray-900"><%= @holiday.name %></h4>
        </div>
        <p class="mt-1 text-sm text-gray-600"><%= Zonely.DateUtils.format_date(@holiday.date) %></p>
      </div>

      <div class="flex items-center space-x-4">
        <!-- Affected users avatars -->
        <div class="flex -space-x-1">
          <div
            :for={user <- @users |> Enum.take(3)}
            class="flex-shrink-0"
            title={user.name}
          >
            <.user_avatar user={user} size={24} class="border-2 border-white" />
          </div>
          <div
            :if={length(@users) > 3}
            class="w-6 h-6 bg-gray-300 rounded-full border-2 border-white flex items-center justify-center"
            title={"#{length(@users) - 3} more"}
          >
            <span class="text-gray-600 font-medium text-xs">
              +<%= length(@users) - 3 %>
            </span>
          </div>
        </div>

        <div class="text-right">
          <div class={[
            "text-sm font-medium",
            @days_until <= 7 && "text-red-700",
            @days_until > 7 && @days_until <= 30 && "text-yellow-700",
            @days_until > 30 && "text-gray-700"
          ]}>
            <%= Zonely.DateUtils.relative_date_text(@holiday.date) %>
          </div>
          <div class="text-xs text-gray-500">
            <%= length(@users) %> members
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a country badge with consistent styling.
  """
  attr :country, :string, required: true, doc: "Country code or name to display"
  attr :size, :atom, default: :normal, values: [:small, :normal, :large], doc: "Size of the badge"
  attr :variant, :atom, default: :gray, values: [:gray, :blue, :green, :yellow], doc: "Color variant"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def country_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-full font-medium",
      badge_size_classes(@size),
      badge_variant_classes(@variant),
      @class
    ]}>
      <%= @country %>
    </span>
    """
  end

  defp badge_size_classes(:small), do: "px-2 py-0.5 text-xs"
  defp badge_size_classes(:normal), do: "px-2.5 py-0.5 text-xs"
  defp badge_size_classes(:large), do: "px-3 py-1 text-sm"

  defp badge_variant_classes(:gray), do: "bg-gray-100 text-gray-800"
  defp badge_variant_classes(:blue), do: "bg-blue-100 text-blue-800"
  defp badge_variant_classes(:green), do: "bg-green-100 text-green-800"
  defp badge_variant_classes(:yellow), do: "bg-yellow-100 text-yellow-800"

  @doc """
  Renders a comprehensive user profile card with all key information.

  This is a composite component that uses other components for consistency.
  """
  attr :user, :map, required: true, doc: "User struct with all user data"
  attr :show_actions, :boolean, default: false, doc: "Whether to show action buttons"
  attr :show_local_time, :boolean, default: false, doc: "Whether to show calculated local time"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def profile_card(assigns) do
    ~H"""
    <div class={[
      "bg-white rounded-lg shadow-lg border border-gray-200 p-6 space-y-4",
      @class
    ]}>
      <!-- Header with avatar and name -->
      <div class="flex items-start gap-4">
        <.user_avatar user={@user} size={64} />

        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2 mb-2">
            <h3 class="text-lg font-semibold text-gray-900 truncate">
              <%= @user.name %>
            </h3>
            <.pronunciation_buttons user={@user} size={:small} />
          </div>

          <p class="text-sm text-gray-600 mb-2">
            <%= @user.role || "Team Member" %>
          </p>

          <!-- Native name display -->
          <div :if={@user.name_native && @user.name_native != @user.name} class="mb-3">
            <label class="block text-xs font-medium text-gray-500 mb-1">
              Native Name (<%= Zonely.LanguageService.get_native_language_name(@user.country) %>)
            </label>
            <p class="text-base font-medium text-gray-900"><%= @user.name_native %></p>
          </div>
        </div>
      </div>

      <!-- Location and timezone -->
      <.timezone_display user={@user} show_local_time={@show_local_time} />

      <!-- Working hours -->
      <.working_hours user={@user} show_status={true} />

      <!-- Actions -->
      <div :if={@show_actions} class="pt-4 border-t border-gray-100">
        <div class="flex gap-2">
          <button
            phx-click="send_message"
            phx-value-user_id={@user.id}
            class="flex-1 px-3 py-2 text-sm font-medium text-blue-700 bg-blue-50 rounded-md hover:bg-blue-100 transition-colors"
          >
            Message
          </button>
          <button
            phx-click="propose_meeting"
            phx-value-user_id={@user.id}
            class="flex-1 px-3 py-2 text-sm font-medium text-emerald-700 bg-emerald-50 rounded-md hover:bg-emerald-100 transition-colors"
          >
            Meeting
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a compact user card suitable for directory listings.

  Optimized for grid layouts with essential information only.
  """
  attr :user, :map, required: true, doc: "User struct"
  attr :clickable, :boolean, default: true, doc: "Whether the card is clickable"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def user_card(assigns) do
    ~H"""
    <div
      class={[
        "bg-white overflow-hidden shadow rounded-lg border border-gray-200 hover:shadow-md transition-shadow p-5",
        @clickable && "cursor-pointer",
        @class
      ]}
      phx-click={@clickable && "show_profile"}
      phx-value-user_id={@clickable && @user.id}
    >
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <.user_avatar user={@user} size={48} />
        </div>

        <div class="ml-5 w-0 flex-1">
          <dl>
            <dt class="text-sm font-medium text-gray-500 truncate flex items-center gap-2">
              <span><%= @user.name %></span>
              <.pronunciation_buttons user={@user} size={:small} show_labels={true} />
            </dt>
            <dd class="text-sm text-gray-900 mt-1">
              <%= @user.role || "Team Member" %>
            </dd>
          </dl>
        </div>
      </div>

      <div class="mt-4">
        <.timezone_display user={@user} layout={:horizontal} />

        <div :if={@user.name_native && @user.name_native != @user.name} class="mt-2">
          <div class="text-xs text-gray-500">
            <%= Zonely.LanguageService.get_native_language_name(@user.country) %>
          </div>
          <div class="text-sm font-medium text-gray-800">
            <%= @user.name_native %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper function for pronunciation button sizes
  defp size_classes_for_pronunciation(:small) do
    %{
      button: "px-2 py-1 text-xs",
      icon: "w-3 h-3",
      text: "text-xs"
    }
  end

  defp size_classes_for_pronunciation(:normal) do
    %{
      button: "px-2 py-1 text-sm",
      icon: "w-3 h-3",
      text: "text-xs"
    }
  end

  defp size_classes_for_pronunciation(:large) do
    %{
      button: "px-3 py-2 text-base",
      icon: "w-4 h-4",
      text: "text-sm"
    }
  end

  @doc """
  Renders a quick actions bar for user interactions.

  Provides common quick actions like messaging, scheduling meetings, and timezone pinning.
  """
  attr :user, :map, required: true, doc: "user struct"
  attr :expanded_action, :string, default: nil, doc: "currently expanded action"
  attr :class, :string, default: "", doc: "additional CSS classes"

  def quick_actions_bar(assigns) do
    ~H"""
    <div class={["bg-white rounded-lg shadow-lg border border-gray-200 p-4", @class]} data-testid="quick-actions-bar">
      <div class="flex items-center justify-between mb-3">
        <h3 class="text-sm font-medium text-gray-800">Quick Actions</h3>
        <span class="text-xs text-gray-500">for <%= @user.name %></span>
      </div>

      <div class="grid grid-cols-3 gap-2">
        <!-- Message Action -->
        <button
          phx-click="quick_message"
          phx-value-user_id={@user.id}
          class="group flex flex-col items-center p-3 rounded-lg border border-gray-200 hover:border-blue-300 hover:bg-blue-50/50 transition-all duration-200"
          data-testid="quick-action-message"
        >
          <.icon name="hero-chat-bubble-left-ellipsis" class="h-5 w-5 text-gray-600 group-hover:text-blue-600 mb-1" />
          <span class="text-xs text-gray-600 group-hover:text-blue-600 font-medium">Message</span>
        </button>

        <!-- Meeting Action -->
        <button
          phx-click="quick_meeting"
          phx-value-user_id={@user.id}
          class="group flex flex-col items-center p-3 rounded-lg border border-gray-200 hover:border-green-300 hover:bg-green-50/50 transition-all duration-200"
          data-testid="quick-action-meeting"
        >
          <.icon name="hero-calendar-days" class="h-5 w-5 text-gray-600 group-hover:text-green-600 mb-1" />
          <span class="text-xs text-gray-600 group-hover:text-green-600 font-medium">Meeting</span>
        </button>

        <!-- Pin Timezone Action -->
        <button
          phx-click="quick_pin"
          phx-value-user_id={@user.id}
          class="group flex flex-col items-center p-3 rounded-lg border border-gray-200 hover:border-orange-300 hover:bg-orange-50/50 transition-all duration-200"
          data-testid="quick-action-pin"
        >
          <.icon name="hero-map-pin" class="h-5 w-5 text-gray-600 group-hover:text-orange-600 mb-1" />
          <span class="text-xs text-gray-600 group-hover:text-orange-600 font-medium">Pin TZ</span>
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a time range selector with drag functionality.

  This component provides a visual time selector for working hours overlap analysis.
  """
  attr :expanded, :boolean, default: true, doc: "whether the panel is expanded"
  attr :class, :string, default: "", doc: "additional CSS classes"
  attr :selected_a_frac, :float, default: nil, doc: "start fraction of selected range (0..1)"
  attr :selected_b_frac, :float, default: nil, doc: "end fraction of selected range (0..1)"
  # Removed server persistence wiring for selection

  def time_range_selector(assigns) do
    ~H"""
    <div class={[
      "bg-white rounded-xl shadow-xl border border-gray-200 max-w-4xl w-full p-6 transition-all duration-300",
      if(@expanded, do: "opacity-100 scale-100", else: "opacity-0 scale-95 h-0 overflow-hidden p-0"),
      @class
    ]}>
      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <div>
          <h3 class="text-lg font-semibold text-gray-800">Working Hours Overlap</h3>
          <p class="text-sm text-gray-500">Drag to select a time range and see team availability</p>
        </div>
        <div class="text-right">
          <div class="text-sm font-medium text-gray-700" id="time-display">No selection</div>
          <div class="text-xs text-gray-500" id="duration-display">Drag to select</div>
        </div>
      </div>

      <!-- Time Slider -->
      <div class="relative">
        <!-- Hour labels (top) -->
        <div class="flex justify-between mb-2 text-xs font-medium text-gray-600">
          <%= for hour <- [0, 6, 12, 18] do %>
            <span class="transform -translate-x-1/2">
              <%= if hour == 0, do: "Midnight", else: (if hour == 12, do: "Noon", else: (if hour > 12, do: "#{hour-12}PM", else: "#{hour}AM")) %>
            </span>
          <% end %>
        </div>

        <!-- Main slider area with clear drag target -->
        <div
          id="time-scrubber"
          phx-hook="TimeScrubber"
          class="relative h-16 bg-white rounded-lg border-2 border-dashed border-blue-300 hover:border-blue-500 hover:bg-blue-50/30 transition-all duration-200 cursor-grab active:cursor-grabbing"
        >
          <!-- Hour grid -->
          <div class="absolute inset-2 flex">
            <%= for hour <- 0..23 do %>
              <div class="flex-1 relative">
                <%= if rem(hour, 6) == 0 do %>
                  <div class="absolute top-0 bottom-0 left-0 w-px bg-blue-300"></div>
                <% else %>
                  <div class="absolute top-0 bottom-0 left-0 w-px bg-gray-200"></div>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Drag instruction -->
          <div class="absolute inset-0 flex items-center justify-center" id="instruction-text">
            <div class="bg-blue-100 text-blue-700 px-4 py-2 rounded-lg border border-blue-200 flex items-center gap-2">
              <.icon name="hero-cursor-arrow-rays" class="w-5 h-5" />
              <span class="font-medium">Click and drag across hours</span>
            </div>
          </div>

          <!-- Selection highlight -->
          <div id="scrubber-selection" class="absolute inset-y-0 bg-blue-200/60 border-l-2 border-r-2 border-blue-500 hidden">
            <!-- Start handle (draggable) -->
            <div class="absolute left-0 top-1/2 transform -translate-y-1/2 -translate-x-3 w-6 h-10 bg-blue-500 rounded-lg shadow-lg flex items-center justify-center cursor-ew-resize hover:bg-blue-600 transition-colors">
              <div class="w-1 h-4 bg-white rounded"></div>
            </div>
            <!-- End handle (draggable) -->
            <div class="absolute right-0 top-1/2 transform -translate-y-1/2 translate-x-3 w-6 h-10 bg-blue-500 rounded-lg shadow-lg flex items-center justify-center cursor-ew-resize hover:bg-blue-600 transition-colors">
              <div class="w-1 h-4 bg-white rounded"></div>
            </div>
          </div>
        </div>

        <!-- Detailed hour markers -->
        <div class="flex justify-between mt-2 text-xs text-gray-400">
          <%= for hour <- 0..23 do %>
            <%= if rem(hour, 3) == 0 do %>
              <span class="text-center w-0">
                <%= "#{hour}" %>
              </span>
            <% else %>
              <span class="w-0"></span>
            <% end %>
          <% end %>
        </div>
      </div>

      <!-- Legend / Actions -->
      <div class="mt-4 flex items-center justify-center gap-8 text-sm">
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 bg-green-500 rounded-full shadow-sm"></div>
          <span class="text-gray-600">Working</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 bg-yellow-500 rounded-full shadow-sm"></div>
          <span class="text-gray-600">Flexible Hours</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 bg-gray-400 rounded-full shadow-sm"></div>
          <span class="text-gray-600">Off Work</span>
        </div>
        <!-- Clear Selection button removed while server persistence is disabled -->
      </div>
    </div>
    """
  end

  @doc """
  Renders a collapsible panel toggle button.
  """
  attr :expanded, :boolean, required: true, doc: "whether the panel is expanded"
  attr :label, :string, required: true, doc: "button label"
  attr :collapsed_label, :string, default: nil, doc: "label when collapsed"
  attr :click_event, :string, required: true, doc: "Phoenix event to trigger"
  attr :class, :string, default: "", doc: "additional CSS classes"

  def panel_toggle(assigns) do
    assigns = assign(assigns, collapsed_label: assigns.collapsed_label || assigns.label)

    ~H"""
    <button
      phx-click={@click_event}
      class={[
        "bg-white rounded-full shadow-lg border border-gray-200 p-3 hover:shadow-xl",
        "flex items-center gap-2 text-gray-700 hover:text-blue-600 transition-all duration-200",
        @class
      ]}
      data-testid="panel-toggle"
    >
      <.icon name="hero-chevron-down" class={"w-5 h-5 transition-transform duration-200 #{if @expanded, do: "rotate-180", else: ""}"} />
      <span class="text-sm font-medium">
        <%= if @expanded, do: @label, else: @collapsed_label %>
      </span>
    </button>
    """
  end
end
