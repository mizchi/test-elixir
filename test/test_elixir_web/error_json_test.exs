defmodule TestElixirWeb.ErrorJSONTest do
  use ExUnit.Case, async: true

  test "renders Phoenix status messages" do
    assert TestElixirWeb.ErrorJSON.render("404.json", %{}) == %{
             errors: %{detail: "Not Found"}
           }
  end
end
