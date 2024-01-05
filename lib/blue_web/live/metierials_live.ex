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
    <h1><%= @blueprint["friendlyname"] %></h1>
    <pre>
      <%= Jason.encode!(@materials, pretty: true) %>
    </pre>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, blueprint} = Original.by_name("terrasieve")
    materials = prepare_mats(blueprint)

    if connected?(socket), do: send_tick()

    {:ok, assign(socket, counter: 0, blueprint: blueprint, materials: materials)}
  end

  def handle_event("inc_temperature", _params, socket) do
    {:noreply, update(socket, :temperature, &(&1 + 1))}
  end

  def handle_info(:tick, socket) do
    send_tick()
    {:noreply, update(socket, :counter, &(&1 + 1))}
  end

defp send_tick do
  Process.send_after(self(), :tick, 1000)
end

  #   <%= for %{"buildingdef" => bid, "selected_elements" => eids} <- @materials do %>
  #   <div></div>
  # <% end %>

  defp prepare_mats(blueprint) do
    materials =
      blueprint
      |> Blueprint.distinct_materials()
      |> Enum.map(fn %{"buildingdef" => bid, "selected_elements" => hashs} ->
        elements = Enum.map(hashs, fn hash -> Map.from_struct(Element.find!(hash)) end)

        %{"building_name" => Building.name_of!(bid), "buildingdef" => bid, "selected_elements" => elements}

      end)
  end
end
