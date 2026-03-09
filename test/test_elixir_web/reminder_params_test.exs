defmodule TestElixirWeb.ReminderParamsTest do
  use ExUnit.Case, async: true

  alias TestElixirWeb.ReminderParams

  test "parses valid create params" do
    assert {:ok, %{title: "Pay rent", due_on: ~D[2026-03-15]}} =
             ReminderParams.parse_create(%{
               "title" => "Pay rent",
               "due_on" => "2026-03-15"
             })
  end

  test "requires due_on" do
    assert {:error, :invalid_due_on} =
             ReminderParams.parse_create(%{
               "title" => "Pay rent"
             })
  end

  test "requires title" do
    assert {:error, :blank_title} = ReminderParams.parse_create(%{})
  end
end
