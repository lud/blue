defmodule BlueWeb.BlueprintDownloadController do
  alias Blue.Blueprint
  use BlueWeb, :controller

  def download(conn, %{"socket_id" => socket_id}) do
    with [{_, changes}] <- Registry.lookup(Blue.ReplacementsRegistry, {socket_id, :changes}),
         [{_, blueprint}] <- Registry.lookup(Blue.ReplacementsRegistry, {socket_id, :blueprint}) do
      do_download(conn, blueprint, changes)
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not found"})
    end
  end

  defp do_download(conn, blueprint, changes) do
    blueprint =
      blueprint
      |> Blueprint.replace_materials(changes.materials_replacements)
      |> Blueprint.change_name(changes.friendlyname)

    json(conn, blueprint)
  end
end
