defmodule Blue.Originals do
  def base_dir do
    Application.fetch_env!(:blue, :blueprints_dir)
  end

  def by_name(name) do
    path = Path.join(base_dir(), "#{name}.blueprint")

    with {:ok, json} <- File.read(path) do
      Jason.decode(json)
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
