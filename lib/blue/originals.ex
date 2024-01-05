defmodule Blue.Originals do
  def base_dir do
    Application.fetch_env!(:blue, :blueprints_dir)
  end
end
