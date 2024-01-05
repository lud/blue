defmodule BlueWeb.MaterialsLive do
  alias Blue.Blueprint
  alias Blue.Element
  alias Blue.Original
  alias Blue.Building
  # In Phoenix v1.6+ apps, the line is typically: use MyAppWeb, :live_view
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div><%= @counter %></div>
    <pre>
      <%= Jason.encode!(@materials, pretty: true) %>
    </pre>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, blueprint} = Original.by_name("terrasieve")
    materials = prepare_mats(blueprint)
    :timer.send_interval(1000, :tick)

    {:ok, assign(socket, counter: 0, blueprint: blueprint, materials: materials)}
  end

  def handle_event("inc_temperature", _params, socket) do
    {:noreply, update(socket, :temperature, &(&1 + 1))}
  end

  def handle_info(:tick, socket) do
    {:noreply, update(socket, :counter, &(&1 + 1))}
  end

  #   <%= for %{"buildingdef" => bid, "selected_elements" => eids} <- @materials do %>
  #   <div></div>
  # <% end %>

  defp prepare_mats(blueprint) do
    materials =
      blueprint
      |> Blueprint.distinct_materials()
      |> Enum.map(fn %{"buildingdef" => bid, "selected_elements" => eids} ->
        %{
          building: Building.name_of!(bid),
          elements: eids |> Enum.map(fn eid -> Element.find!(eid).name end)
        }
      end)
  end
end
