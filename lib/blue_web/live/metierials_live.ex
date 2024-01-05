defmodule BlueWeb.MaterialsLive do
  alias Blue.Blueprint
  alias Blue.Original
  # In Phoenix v1.6+ apps, the line is typically: use MyAppWeb, :live_view
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    Current temperature: <%= @temperature %>°F <button phx-click="inc_temperature">+</button>
    <pre>
      <%= Jason.encode!(@materials, pretty: true) %>
    </pre>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, blueprint} = Original.by_name("terrasieve")
    materials = Blueprint.distinct_materials(blueprint)

    # Let's assume a fixed temperature for now
    temperature = 70
    {:ok, assign(socket, temperature: temperature, blueprint: blueprint, materials: materials)}
  end

  def handle_event("inc_temperature", _params, socket) do
    {:noreply, update(socket, :temperature, &(&1 + 1))}
  end
end
